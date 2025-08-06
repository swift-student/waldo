//
//  RepoTests.swift
//  GitTests
//
//  Created by Shawn Gee on 7/21/25.
//

import Foundation
@testable import Git
import PrintDebug
import Testing

@Suite("Git Repository with Temporary Repo")
struct GitRepoTests {
    // Helper method to create a test environment
    static func withTestRepo<T>(
        _ test: (Git.Repo, URL) throws -> T
    ) throws -> T {
        // Create temporary directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitTest-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: tempDir)
            try? Git.shutdown()
        }

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try setUpTestRepo(at: tempDir)

        try Git.initialize()
        let repo = try Git.Repo(url: tempDir)

        return try test(repo, tempDir)
    }

    @Test("Diff name-status between commits")
    func diffNameStatus() throws {
        try Self.withTestRepo { repo, _ in
            let changes = try repo.diffNameStatus(from: "HEAD~1", to: "HEAD")

            #expect(changes.count == 2)

            #expect(changes[0].path == "file1.txt")
            #expect(changes[0].status == .modified)
            #expect(changes[1].path == "file2.txt")
            #expect(changes[1].status == .added)
        }
    }

    @Test("Diff with no changes")
    func diffNameStatusWithNoChanges() throws {
        try Self.withTestRepo { repo, _ in
            // Comparing HEAD with itself should return no changes
            let changes = try repo.diffNameStatus(from: "HEAD", to: "HEAD")
            #expect(changes.count == 0)
        }
    }

    @Test("Diff with deleted file")
    func diffNameStatusWithDeletedFile() throws {
        try Self.withTestRepo { repo, tempDir in
            try Self.deleteFile("file2.txt", in: tempDir)
            try Self.runGitCommand(["add", "."], in: tempDir)
            try Self.runGitCommand(["commit", "-m", "Delete file2"], in: tempDir)

            let changes = try repo.diffNameStatus(from: "HEAD~1", to: "HEAD")

            #expect(changes.count == 1)
            #expect(changes[0].path == "file2.txt")
            #expect(changes[0].status == .deleted)
        }
    }

    @Test("Invalid reference throws error")
    func invalidReference() throws {
        try Self.withTestRepo { repo, _ in
            #expect(throws: GitError.self) {
                try repo.diffNameStatus(from: "invalid-ref", to: "HEAD")
            }
        }
    }

    @Test("Different revision syntaxes")
    func differentRevisionSyntaxes() throws {
        try Self.withTestRepo { repo, _ in
            // Test various ways to reference commits
            let changes1 = try repo.diffNameStatus(from: "HEAD~1", to: "HEAD")
            let changes2 = try repo.diffNameStatus(from: "HEAD^", to: "HEAD")

            // HEAD~1 and HEAD^ should be equivalent for linear history
            #expect(changes1.count == changes2.count)

            // Test that we can use HEAD directly
            let noChanges = try repo.diffNameStatus(from: "HEAD", to: "HEAD")
            #expect(noChanges.isEmpty)
        }
    }

    @Test("Diff working tree with staged and unstaged changes")
    func diffNameStatusWorkingTree() throws {
        try Self.withTestRepo { repo, tempDir in
            // Modify existing file (unstaged)
            try Self.writeToFile("file1.txt", content: "Modified content", in: tempDir)

            // Add new file and stage it
            try Self.writeToFile("file3.txt", content: "New file", in: tempDir)
            try Self.runGitCommand(["add", "file3.txt"], in: tempDir)

            // Stage a modification to file2, then modify it again (both staged and unstaged)
            try Self.writeToFile("file2.txt", content: "Staged change", in: tempDir)
            try Self.runGitCommand(["add", "file2.txt"], in: tempDir)
            try Self.writeToFile("file2.txt", content: "Staged + unstaged change", in: tempDir)

            let changes = try repo.diffNameStatusWorkingTree()

            #expect(changes.count == 3)
            #expect(changes[0].path == "file1.txt")
            #expect(changes[0].status == .modified)
            #expect(changes[1].path == "file2.txt")
            #expect(changes[1].status == .modified)
            #expect(changes[2].path == "file3.txt")
            #expect(changes[2].status == .added)
        }
    }

    @Test("Status - modified, staged, and untracked files")
    func status() throws {
        try Self.withTestRepo { repo, tempDir in
            // Modify an existing file (unstaged)
            try Self.writeToFile("file1.txt", content: "Modified in working tree", in: tempDir)

            // Modify and stage a file, then modify it again (both staged and unstaged changes)
            try Self.writeToFile("file2.txt", content: "First modification", in: tempDir)
            try Self.runGitCommand(["add", "file2.txt"], in: tempDir)
            try Self.writeToFile("file2.txt", content: "Second modification", in: tempDir)

            // Add a new file and stage it
            try Self.writeToFile("staged_new.txt", content: "New staged file", in: tempDir)
            try Self.runGitCommand(["add", "staged_new.txt"], in: tempDir)

            // Add untracked files
            try Self.writeToFile("untracked1.txt", content: "Untracked 1", in: tempDir)
            try Self.writeToFile("untracked2.txt", content: "Untracked 2", in: tempDir)

            let allStatus = try repo.status()

            #expect(allStatus.count == 5)

            // Check for specific files
            let untrackedFiles = allStatus.filter { $0.status == .untracked }
            #expect(untrackedFiles.count == 2)
            #expect(untrackedFiles.contains { $0.path == "untracked1.txt" })
            #expect(untrackedFiles.contains { $0.path == "untracked2.txt" })

            let modifiedFiles = allStatus.filter { $0.status == .modified }
            #expect(modifiedFiles.count == 2)
            #expect(modifiedFiles.contains { $0.path == "file1.txt" })
            #expect(modifiedFiles.contains { $0.path == "file2.txt" })

            let addedFiles = allStatus.filter { $0.status == .added }
            #expect(addedFiles.count == 1)
            #expect(addedFiles.contains { $0.path == "staged_new.txt" })
        }
    }

    @Test("Unified status - empty repository")
    func unifiedStatusEmptyRepo() throws {
        try Self.withTestRepo { repo, _ in
            let status = try repo.status(includeUntracked: true, includeIgnored: false)
            #expect(status.isEmpty)
        }
    }

    // MARK: - Static Helper Methods

    static func setUpTestRepo(at tempDir: URL) throws {
        // git init
        try runGitCommand(["init"], in: tempDir)

        // Configure git user (required for commits)
        try runGitCommand(["config", "user.name", "Test User"], in: tempDir)
        try runGitCommand(["config", "user.email", "test@example.com"], in: tempDir)

        // Create initial commit
        try writeToFile("file1.txt", content: "Hello", in: tempDir)
        try runGitCommand(["add", "file1.txt"], in: tempDir)
        try runGitCommand(["commit", "-m", "Initial commit"], in: tempDir)

        // Create second commit with changes
        try writeToFile("file2.txt", content: "World", in: tempDir)
        try writeToFile("file1.txt", content: "Hello Modified", in: tempDir) // Modify existing file
        try runGitCommand(["add", "."], in: tempDir)
        try runGitCommand(["commit", "-m", "Second commit"], in: tempDir)
    }

    static func writeToFile(_ name: String, content: String, in directory: URL) throws {
        let url = directory.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    static func deleteFile(_ name: String, in directory: URL) throws {
        let url = directory.appendingPathComponent(name)
        try FileManager.default.removeItem(at: url)
    }

    static func runGitCommand(_ args: [String], in directory: URL) throws {
        let process = Process()
        process.currentDirectoryPath = directory.path
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args

        // Capture output for debugging
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let standardOutput = String(data: outputData, encoding: .utf8) ?? ""

            let message = """
            Git command failed: git \(args.joined(separator: " "))
            Exit code: \(process.terminationStatus)
            Standard output: \(standardOutput)
            Error output: \(errorOutput)
            """

            struct GitCommandError: Error, CustomStringConvertible {
                let description: String
            }

            throw GitCommandError(description: message)
        }
    }

}
