//
//  GitError.swift
//  Diffi
//
//  Created by Shawn Gee on 7/17/25.
//

import Clibgit2

enum GitError: Error, CustomDebugStringConvertible {
    case libraryFailedToInitialize(Clibgit2Error)
    case libraryFailedToShutdown(Clibgit2Error)
    case failedToOpenRepo(Clibgit2Error)
    case failedToResolveReference(Clibgit2Error)
    case failedToLookupCommit(Clibgit2Error)
    case failedToGetCommitTree(Clibgit2Error)
    case failedToCreateDiff(Clibgit2Error)

    var debugDescription: String {
        switch self {
        case let .libraryFailedToInitialize(error):
            "Library failed to initialize: \(error)"
        case let .libraryFailedToShutdown(error):
            "Library failed to shutdown: \(error)"
        case let .failedToOpenRepo(error):
            "Failed to open repo: \(error)"
        case let .failedToResolveReference(error):
            "Failed to resolve reference: \(error)"
        case let .failedToLookupCommit(error):
            "Failed to lookup commit: \(error)"
        case let .failedToGetCommitTree(error):
            "Failed to get commit tree: \(error)"
        case let .failedToCreateDiff(error):
            "Failed to create diff: \(error)"
        }
    }
}
