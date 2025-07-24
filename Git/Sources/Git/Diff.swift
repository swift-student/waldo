import Clibgit2

public extension Git {
    enum Diff {
        typealias Delta = git_diff_delta

        public enum Status: Equatable {
            case unmodified
            case added
            case deleted
            case modified
            case renamed
            case copied
            case ignored
            case untracked
            case typechange
            case unreadable
            case conflicted
            case unknown

            init(_ gitStatus: git_delta_t) {
                switch gitStatus {
                case GIT_DELTA_UNMODIFIED:
                    self = .unmodified
                case GIT_DELTA_ADDED:
                    self = .added
                case GIT_DELTA_DELETED:
                    self = .deleted
                case GIT_DELTA_MODIFIED:
                    self = .modified
                case GIT_DELTA_RENAMED:
                    self = .renamed
                case GIT_DELTA_COPIED:
                    self = .copied
                case GIT_DELTA_IGNORED:
                    self = .ignored
                case GIT_DELTA_UNTRACKED:
                    self = .untracked
                case GIT_DELTA_TYPECHANGE:
                    self = .typechange
                case GIT_DELTA_UNREADABLE:
                    self = .unreadable
                case GIT_DELTA_CONFLICTED:
                    self = .conflicted
                default:
                    self = .unknown
                }
            }

            public var singleCharacter: String {
                switch self {
                case .unmodified:
                    return " "
                case .added:
                    return "A"
                case .deleted:
                    return "D"
                case .modified:
                    return "M"
                case .renamed:
                    return "R"
                case .copied:
                    return "C"
                case .ignored:
                    return "!"
                case .untracked:
                    return "?"
                case .typechange:
                    return "T"
                case .unreadable:
                    return "X"
                case .conflicted:
                    return "U"
                case .unknown:
                    return "?"
                }
            }
        }

        public struct FileChange: Equatable {
            public let status: Status
            public let path: String
        }

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

        static func treeToWorkingDirectory(repo: OpaquePointer, oldTree: OpaquePointer?) throws(GitError) -> OpaquePointer {
            var diff: OpaquePointer?

            let returnCode = git_diff_tree_to_workdir_with_index(&diff, repo, oldTree, nil)

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
