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
