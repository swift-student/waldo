import Clibgit2

extension Git {
    enum Tree {
        // MARK: - Tree Operations

        static func free(_ tree: OpaquePointer) {
            git_tree_free(tree)
        }
    }
}
