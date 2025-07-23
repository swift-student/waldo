//
//  Git.swift
//  Diffi
//
//  Created by Shawn Gee on 7/21/25.
//

import Clibgit2
import Foundation

typealias GitOID = git_oid

public enum Git {
    static func initialize() throws {
        try Git.libgit2Init()
    }

    static func shutdown() throws {
        try Git.libgit2Shutdown()
    }
}

extension Git {
    static func libgit2Init() throws(GitError) {
        if let errorCode = Clibgit2ErrorCode(returnCode: git_libgit2_init()) {
            throw .libraryFailedToInitialize(.init(code: errorCode))
        }
    }

    static func libgit2Shutdown() throws(GitError) {
        if let errorCode = Clibgit2ErrorCode(returnCode: git_libgit2_shutdown()) {
            throw .libraryFailedToShutdown(.init(code: errorCode))
        }
    }

    // For revision expressions like "HEAD~1", "main@{2.days.ago}", etc.
    static func revparseSingle(repo: OpaquePointer, revspec: String) throws(GitError) -> GitOID {
        var obj: OpaquePointer?

        let returnCode = git_revparse_single(&obj, repo, revspec)
        defer {
            if let obj = obj {
                git_object_free(obj)
            }
        }

        guard let obj = obj else {
            throw .failedToResolveReference(
                Clibgit2Error(code: Clibgit2ErrorCode(returnCode: returnCode) ?? .unknown)
            )
        }

        return git_object_id(obj).pointee
    }

    static func deltaStatusToString(_ status: git_delta_t) -> String {
        switch status {
        case GIT_DELTA_UNMODIFIED:
            return " " // Unchanged (shouldn't appear in typical diff)
        case GIT_DELTA_ADDED:
            return "A"
        case GIT_DELTA_DELETED:
            return "D"
        case GIT_DELTA_MODIFIED:
            return "M"
        case GIT_DELTA_RENAMED:
            return "R"
        case GIT_DELTA_COPIED:
            return "C"
        case GIT_DELTA_IGNORED:
            return "!"
        case GIT_DELTA_UNTRACKED:
            return "?"
        case GIT_DELTA_TYPECHANGE:
            return "T"
        case GIT_DELTA_UNREADABLE:
            return "X"
        case GIT_DELTA_CONFLICTED:
            return "U"
        default:
            return "?"
        }
    }
}
