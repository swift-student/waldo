import Clibgit2

extension Git {
    enum Diff {
        typealias Delta = git_diff_delta

        static func treeToTree(repo: OpaquePointer, oldTree: OpaquePointer?, newTree: OpaquePointer?) throws(GitError) -> OpaquePointer {
            var diff: OpaquePointer?

            let returnCode = git_diff_tree_to_tree(&diff, repo, oldTree, newTree, nil)

            guard let diff else {
                throw .failedToCreateDiff(
                    Clibgit2Error(code: Clibgit2ErrorCode(returnCode: returnCode) ?? .unknown)
                )
            }

            return diff
        }

        static func free(_ diff: OpaquePointer) {
            git_diff_free(diff)
        }

        static func numDeltas(_ diff: OpaquePointer) -> Int {
            return git_diff_num_deltas(diff)
        }

        static func getDelta(_ diff: OpaquePointer, index: Int) -> UnsafePointer<Delta>? {
            return git_diff_get_delta(diff, index)!
        }
    }
}
