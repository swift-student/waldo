import Clibgit2
import Foundation

public extension Git {
    class Repo {
        let repo: OpaquePointer

        init(url: URL) throws {
            repo = try Self.open(url: url)
        }

        deinit {
            Self.free(repo)
        }

        func diffNameStatus(from: String, to: String) throws -> [(status: String, path: String)] {
            let fromOID = try Git.revparseSingle(repo: repo, revspec: from)
            let toOID = try Git.revparseSingle(repo: repo, revspec: to)

            let fromTree = try getTreeFromCommit(oid: fromOID)
            defer { Git.Tree.free(fromTree) }

            let toTree = try getTreeFromCommit(oid: toOID)
            defer { Git.Tree.free(toTree) }

            let diff = try Git.Diff.treeToTree(repo: repo, oldTree: fromTree, newTree: toTree)
            defer { Git.Diff.free(diff) }

            // 4. Iterate through the diff deltas to extract name-status info
            let numDeltas = Git.Diff.numDeltas(diff)
            var results: [(status: String, path: String)] = []

            for i in 0 ..< numDeltas {
                guard let delta = Git.Diff.getDelta(diff, index: i) else { continue }

                let status = Git.deltaStatusToString(delta.pointee.status)
                let path = String(cString: delta.pointee.new_file.path)
                results.append((status: status, path: path))
            }

            return results
        }

        private func getTreeFromCommit(oid: GitOID) throws -> OpaquePointer {
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
