import Clibgit2

extension Git {
    enum Commit {
        static func tree(for commit: OpaquePointer) throws(GitError) -> OpaquePointer {
            var tree: OpaquePointer?

            let returnCode = git_commit_tree(&tree, commit)

            guard let tree else {
                throw .failedToGetCommitTree(
                    Clibgit2Error(code: Clibgit2ErrorCode(returnCode: returnCode) ?? .unknown)
                )
            }

            return tree
        }

        static func lookup(repo: OpaquePointer, oid: GitOID) throws(GitError) -> OpaquePointer {
            var commit: OpaquePointer?
            var oid = oid

            let returnCode = git_commit_lookup(&commit, repo, &oid)

            guard let commit else {
                throw .failedToLookupCommit(
                    Clibgit2Error(code: Clibgit2ErrorCode(returnCode: returnCode) ?? .unknown)
                )
            }

            return commit
        }

        static func free(_ commit: OpaquePointer) {
            git_commit_free(commit)
        }
    }
}
