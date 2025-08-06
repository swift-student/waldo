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
            let options = Git.Status.makeOptions(includeUntracked: includeUntracked, includeIgnored: includeIgnored)
            let statusList = try Git.Status.list(repo: repo, options: options)
            defer { Git.Status.free(list: statusList) }

            let count = Git.Status.entryCount(list: statusList)

            return (0 ..< count).compactMap { index in
                guard let entry = Git.Status.entryByIndex(list: statusList, index: index) else {
                    return nil
                }

                return Git.Status.parseEntry(entry, statusFlags: entry.pointee.status)
            }
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
