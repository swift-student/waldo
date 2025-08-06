import Clibgit2
import Foundation

public extension Git {
    class Repo {
        let repo: OpaquePointer

        public init(url: URL) throws(GitError) {
            repo = try Self.open(url: url)
        }

        deinit {
            Self.free(repo)
        }

        public func diffNameStatus(from: String, to: String) throws(GitError) -> [Git.Diff.FileChange] {
            let fromOID = try Git.revparseSingle(repo: repo, revspec: from)
            let toOID = try Git.revparseSingle(repo: repo, revspec: to)

            let fromTree = try getTreeFromCommit(oid: fromOID)
            defer { Git.Tree.free(fromTree) }

            let toTree = try getTreeFromCommit(oid: toOID)
            defer { Git.Tree.free(toTree) }

            let diff = try Git.Diff.treeToTree(repo: repo, oldTree: fromTree, newTree: toTree)
            defer { Git.Diff.free(diff) }

            let numDeltas = Git.Diff.numDeltas(diff)

            return (0 ..< numDeltas).compactMap { index in
                guard let delta = Git.Diff.getDelta(diff, index: index) else { return nil }

                let status = Git.Diff.Status(delta.pointee.status)
                let path = String(cString: delta.pointee.new_file.path)
                return Git.Diff.FileChange(status: status, path: path)
            }
        }

        public func diffNameStatusWorkingTree() throws(GitError) -> [Git.Diff.FileChange] {
            let headOID = try Git.revparseSingle(repo: repo, revspec: "HEAD")

            let headTree = try getTreeFromCommit(oid: headOID)
            defer { Git.Tree.free(headTree) }

            let diff = try Git.Diff.treeToWorkingDirectory(repo: repo, oldTree: headTree)
            defer { Git.Diff.free(diff) }

            let numDeltas = Git.Diff.numDeltas(diff)

            return (0 ..< numDeltas).compactMap { index in
                guard let delta = Git.Diff.getDelta(diff, index: index) else { return nil }

                let status = Git.Diff.Status(delta.pointee.status)
                let path = String(cString: delta.pointee.new_file.path)
                return Git.Diff.FileChange(status: status, path: path)
            }
        }

        public func show(revspec: String, filePath: String) throws(GitError) -> Data {
            let oid = try Git.revparseSingle(repo: repo, revspec: revspec)
            let tree = try getTreeFromCommit(oid: oid)
            defer { Git.Tree.free(tree) }

            let entry = try Git.Tree.entryByPath(tree: tree, path: filePath)
            defer { Git.Tree.entryFree(entry) }

            let blobOID = Git.Tree.entryOID(entry)
            let blob = try Git.Blob.lookup(repo: repo, oid: blobOID)
            defer { Git.Blob.free(blob) }

            return try Git.Blob.data(blob)
        }

        public func status(includeUntracked: Bool = true, includeIgnored: Bool = false) throws(GitError) -> [Git.Diff.FileChange] {
            var statusList: OpaquePointer?
            var options = git_status_options()
            git_status_options_init(&options, UInt32(GIT_STATUS_OPTIONS_VERSION))

            // Configure what to show
            options.show = GIT_STATUS_SHOW_INDEX_AND_WORKDIR

            // Configure flags based on parameters
            var flags: UInt32 = 0
            if includeUntracked {
                flags |= GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue
            }
            if includeIgnored {
                flags |= GIT_STATUS_OPT_INCLUDE_IGNORED.rawValue
            }
            options.flags = flags

            let returnCode = git_status_list_new(&statusList, repo, &options)
            guard let statusList = statusList else {
                throw GitError.failedToGetStatus(
                    Clibgit2Error(code: Clibgit2ErrorCode(returnCode: returnCode) ?? .error)
                )
            }
            defer { git_status_list_free(statusList) }

            let count = git_status_list_entrycount(statusList)

            return (0 ..< count).compactMap { index in
                // Entry is not modifiable and should not be freed
                guard let entry = git_status_byindex(statusList, index) else {
                    return nil
                }

                return parseStatusEntry(entry: entry, statusFlags: entry.pointee.status)
            }
        }

        private func parseStatusEntry(entry: UnsafePointer<git_status_entry>, statusFlags: git_status_t) -> Git.Diff.FileChange? {
            // Determine the appropriate path based on the status
            var pathPointer: UnsafePointer<CChar>?

            // For untracked files, use index_to_workdir
            if statusFlags.rawValue & GIT_STATUS_WT_NEW.rawValue != 0 {
                pathPointer = entry.pointee.index_to_workdir?.pointee.new_file.path
            }

            // For files modified in working tree, use index_to_workdir
            else if statusFlags.rawValue & (GIT_STATUS_WT_MODIFIED.rawValue | GIT_STATUS_WT_DELETED.rawValue | GIT_STATUS_WT_TYPECHANGE.rawValue) != 0 {
                pathPointer = entry.pointee.index_to_workdir?.pointee.new_file.path ?? entry.pointee.index_to_workdir?.pointee.old_file.path
            }

            // For files modified in index, use head_to_index
            else if statusFlags.rawValue & (GIT_STATUS_INDEX_NEW.rawValue | GIT_STATUS_INDEX_MODIFIED.rawValue | GIT_STATUS_INDEX_DELETED.rawValue | GIT_STATUS_INDEX_TYPECHANGE.rawValue) != 0 {
                pathPointer = entry.pointee.head_to_index?.pointee.new_file.path ?? entry.pointee.head_to_index?.pointee.old_file.path
            }

            guard let pathPointer else { return nil }

            let path = String(cString: pathPointer)

            // Convert status flags to our enum
            let status: Git.Diff.Status
            if statusFlags.rawValue & GIT_STATUS_WT_NEW.rawValue != 0 {
                status = .untracked
            } else if statusFlags.rawValue & (GIT_STATUS_WT_MODIFIED.rawValue | GIT_STATUS_INDEX_MODIFIED.rawValue) != 0 {
                status = .modified
            } else if statusFlags.rawValue & (GIT_STATUS_WT_DELETED.rawValue | GIT_STATUS_INDEX_DELETED.rawValue) != 0 {
                status = .deleted
            } else if statusFlags.rawValue & (GIT_STATUS_INDEX_NEW.rawValue) != 0 {
                status = .added
            } else {
                // For other statuses, default to modified
                status = .modified
            }

            return Git.Diff.FileChange(status: status, path: path)
        }

        private func getTreeFromCommit(oid: GitOID) throws(GitError) -> OpaquePointer {
            let commit = try Git.Commit.lookup(repo: repo, oid: oid)
            defer { Git.Commit.free(commit) }

            return try Git.Commit.tree(for: commit)
        }
    }
}

extension Git.Repo {
    static func open(url: URL) throws(GitError) -> OpaquePointer {
        var repo: OpaquePointer?

        let returnCode = url.withUnsafeFileSystemRepresentation { url in
            git_repository_open(&repo, url)
        }

        guard let repo else {
            throw .failedToOpenRepo(
                Clibgit2Error(code: Clibgit2ErrorCode(returnCode: returnCode) ?? .unknown)
            )
        }

        return repo
    }

    static func free(_ repo: OpaquePointer) {
        git_repository_free(repo)
    }
}
