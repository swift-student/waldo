import Clibgit2

extension Git {
    enum Tree {
        // MARK: - Tree Operations

        static func free(_ tree: OpaquePointer) {
            git_tree_free(tree)
        }
        
        static func entryByPath(tree: OpaquePointer, path: String) throws(GitError) -> OpaquePointer {
            var entry: OpaquePointer?
            
            let returnCode = git_tree_entry_bypath(&entry, tree, path)
            
            guard let entry else {
                throw .failedToFindTreeEntry(
                    Clibgit2Error(code: Clibgit2ErrorCode(returnCode: returnCode) ?? .unknown)
                )
            }
            
            return entry
        }
        
        static func entryOID(_ entry: OpaquePointer) -> GitOID {
            return git_tree_entry_id(entry).pointee
        }
        
        static func entryFree(_ entry: OpaquePointer) {
            git_tree_entry_free(entry)
        }
    }
}
