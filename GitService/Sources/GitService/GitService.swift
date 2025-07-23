//
//  GitService.swift
//  Diffi
//
//  Created by Shawn Gee on 7/17/25.
//

import Clibgit2
import Foundation
import PrintDebug

enum GitLibrary {
    static func initialize() throws {
        try Git.libgit2Init()
    }

    static func shutdown() throws {
        try Git.libgit2Shutdown()
    }
}

class GitRepository {
    let repo: OpaquePointer

    init(url: URL) throws {
        repo = try Git.repositoryOpen(url: url)
    }

    deinit {
        Git.repositoryFree(repo)
    }
    
    func diffNameStatus(from: String, to: String) throws -> [(status: String, path: String)] {
        let fromOID = try Git.revparseSingle(repo: repo, revspec: from)
        let toOID = try Git.revparseSingle(repo: repo, revspec: to)
        
        let fromTree = try getTreeFromCommit(oid: fromOID)
        defer { Git.treeFree(fromTree) }
        
        let toTree = try getTreeFromCommit(oid: toOID)
        defer { Git.treeFree(toTree) }
        
        let diff = try Git.diffTreeToTree(repo: repo, oldTree: fromTree, newTree: toTree)
        defer { Git.diffFree(diff) }
        
        // 4. Iterate through the diff deltas to extract name-status info
        let numDeltas = Git.diffNumDeltas(diff)
        var results: [(status: String, path: String)] = []
        
        for i in 0..<numDeltas {
            let delta = Git.diffGetDelta(diff, index: i)
            let status = Git.deltaStatusToString(delta.pointee.status)
            let path = String(cString: delta.pointee.new_file.path)
            results.append((status: status, path: path))
        }
        
        return results
    }
    
    private func getTreeFromCommit(oid: GitOID) throws -> OpaquePointer {
        let commit = try Git.commitLookup(repo: repo, oid: oid)
        defer { Git.commitFree(commit) }
        
        return try Git.commitTree(commit: commit)
    }
}


enum GitServiceError: Error, CustomDebugStringConvertible {
    case libraryFailedToInitialize(GitError)
    case libraryFailedToShutdown(GitError)
    case failedToOpenRepo(GitError)
    case failedToResolveReference(GitError)
    case failedToLookupCommit(GitError) 
    case failedToGetCommitTree(GitError)
    case failedToCreateDiff(GitError)

    var debugDescription: String {
        switch self {
        case let .libraryFailedToInitialize(gitError):
            "Library failed to initialize: \(gitError)"
        case let .libraryFailedToShutdown(gitError):
            "Library failed to shutdown: \(gitError)"
        case let .failedToOpenRepo(gitError):
            "Failed to open repo: \(gitError)"
        case let .failedToResolveReference(gitError):
            "Failed to resolve reference: \(gitError)"
        case let .failedToLookupCommit(gitError):
            "Failed to lookup commit: \(gitError)" 
        case let .failedToGetCommitTree(gitError):
            "Failed to get commit tree: \(gitError)"
        case let .failedToCreateDiff(gitError):
            "Failed to create diff: \(gitError)"
        }
    }
}


