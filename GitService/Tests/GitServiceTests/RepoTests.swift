//
//  RepoTests.swift
//  GitServiceTests
//
//  Created by Shawn Gee on 7/21/25.
//

import Foundation
@testable import GitService
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

    // MARK: - Static Helper Methods

    static func setUpTestRepo(at tempDir: URL) throws {
        // git init
        try runGitCommand(["init"], in: tempDir)

        // Configure git user (required for commits)
        try runGitCommand(["config", "user.name", "Test User"], in: tempDir)
        try runGitCommand(["config", "user.email", "test@example.com"], in: tempDir)

        // Create initial commit
        try createFile("file1.txt", content: "Hello", in: tempDir)
        try runGitCommand(["add", "file1.txt"], in: tempDir)
        try runGitCommand(["commit", "-m", "Initial commit"], in: tempDir)

        // Create second commit with changes
        try createFile("file2.txt", content: "World", in: tempDir)
        try createFile("file1.txt", content: "Hello Modified", in: tempDir) // Modify existing file
        try runGitCommand(["add", "."], in: tempDir)
        try runGitCommand(["commit", "-m", "Second commit"], in: tempDir)
    }

    static func createFile(_ name: String, content: String, in directory: URL) throws {
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
