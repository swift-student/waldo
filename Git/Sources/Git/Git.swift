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
    public static func initialize() throws {
        try Git.libgit2Init()
    }

    public static func shutdown() throws {
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
}
