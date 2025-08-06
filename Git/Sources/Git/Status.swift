import Clibgit2

extension Git {
    enum Status {
        static func list(repo: OpaquePointer, options: git_status_options) throws(GitError) -> OpaquePointer {
            var statusList: OpaquePointer?
            var options = options

            let returnCode = git_status_list_new(&statusList, repo, &options)

            guard let statusList else {
                throw .failedToGetStatus(
                    Clibgit2Error(code: Clibgit2ErrorCode(returnCode: returnCode) ?? .error)
                )
            }

            return statusList
        }

        static func free(list statusList: OpaquePointer) {
            git_status_list_free(statusList)
        }

        static func entryCount(list statusList: OpaquePointer) -> Int {
            return git_status_list_entrycount(statusList)
        }

        static func entryByIndex(list statusList: OpaquePointer, index: Int) -> UnsafePointer<git_status_entry>? {
            return git_status_byindex(statusList, index)
        }

        static func parseEntry(_ entry: UnsafePointer<git_status_entry>, statusFlags: git_status_t) -> Git.Diff.FileChange? {
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

        static func makeOptions(includeUntracked: Bool, includeIgnored: Bool) -> git_status_options {
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

            return options
        }
    }
}

