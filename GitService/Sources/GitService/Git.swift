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
    // MARK: - Library

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

    // MARK: - Repository

    static func repositoryOpen(url: URL) throws(GitError) -> OpaquePointer {
        var repo: OpaquePointer?

        let returnCode = url.withUnsafeFileSystemRepresentation { url in
            git_repository_open(&repo, url)
        }

        guard let repo else {
            throw .failedToOpenRepo(
                Clibgit2Error(code: Clibgit2ErrorCode(returnCode: returnCode) ?? .unknown)
            )
        }

        return repo
    }

    static func repositoryFree(_ repo: OpaquePointer) {
        git_repository_free(repo)
    }

    // MARK: - Reference Resolution

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

    // MARK: - Commit Operations

    static func commitLookup(repo: OpaquePointer, oid: GitOID) throws(GitError) -> OpaquePointer {
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

    static func commitFree(_ commit: OpaquePointer) {
        git_commit_free(commit)
    }

    static func commitTree(commit: OpaquePointer) throws(GitError) -> OpaquePointer {
        var tree: OpaquePointer?

        let returnCode = git_commit_tree(&tree, commit)

        guard let tree else {
            throw .failedToGetCommitTree(
                Clibgit2Error(code: Clibgit2ErrorCode(returnCode: returnCode) ?? .unknown)
            )
        }

        return tree
    }

    // MARK: - Tree Operations

    static func treeFree(_ tree: OpaquePointer) {
        git_tree_free(tree)
    }

    // MARK: - Diff Operations

    static func diffTreeToTree(repo: OpaquePointer, oldTree: OpaquePointer?, newTree: OpaquePointer?) throws(GitError) -> OpaquePointer {
        var diff: OpaquePointer?

        let returnCode = git_diff_tree_to_tree(&diff, repo, oldTree, newTree, nil)

        guard let diff else {
            throw .failedToCreateDiff(
                Clibgit2Error(code: Clibgit2ErrorCode(returnCode: returnCode) ?? .unknown)
            )
        }

        return diff
    }

    static func diffFree(_ diff: OpaquePointer) {
        git_diff_free(diff)
    }

    static func diffNumDeltas(_ diff: OpaquePointer) -> Int {
        return git_diff_num_deltas(diff)
    }

    static func diffGetDelta(_ diff: OpaquePointer, index: Int) -> UnsafePointer<git_diff_delta> {
        return git_diff_get_delta(diff, index)!
    }

    // MARK: - Helper for Delta Status

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
