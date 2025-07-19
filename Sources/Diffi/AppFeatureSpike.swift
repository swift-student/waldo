import Clocks
import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
struct AppFeatureSpike {
    @ObservableState
    struct State: Equatable {
        var repositoryPath: URL?
        var changedImageFiles: [String] = []
        var fileStatuses: [String: String] = [:] // filename -> status (A/M)
        var selectedFile: String?
        var showingFolderPicker = false
    }

    enum Action {
        case folderPickerButtonTapped
        case folderSelected(URL)
        case folderPickerDismissed
        case timerTicked
        case gitFilesLoaded([String], [String: String])
        case fileSelected(String?)
    }

    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .folderPickerButtonTapped:
                state.showingFolderPicker = true
                return .none

            case let .folderSelected(url):
                state.repositoryPath = url
                state.showingFolderPicker = false
                return .merge(
                    .send(.timerTicked),
                    .run { send in
                        for await _ in clock.timer(interval: .seconds(2)) {
                            await send(.timerTicked)
                        }
                    }
                )

            case .folderPickerDismissed:
                state.showingFolderPicker = false
                return .none

            case .timerTicked:
                guard let repoPath = state.repositoryPath else { return .none }
                return .run { send in
                    let (files, statuses) = await getChangedImageFiles(at: repoPath)
                    await send(.gitFilesLoaded(files, statuses))
                }

            case let .gitFilesLoaded(files, statuses):
                state.changedImageFiles = files
                state.fileStatuses = statuses
                if !files.contains(where: { $0 == state.selectedFile }) {
                    state.selectedFile = files.first
                }
                return .none

            case let .fileSelected(file):
                state.selectedFile = file
                return .none
            }
        }
    }
}

private func getChangedImageFiles(at repoPath: URL) async -> ([String], [String: String]) {
    let task = Process()
    task.currentDirectoryURL = repoPath
    task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    task.arguments = ["diff", "--name-status", "--diff-filter=AM", "HEAD"]

    let pipe = Pipe()
    task.standardOutput = pipe

    do {
        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        print("Git output: '\(output)'")
        print("Git output lines: \(output.components(separatedBy: .newlines))")

        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp"]
        var files: [String] = []
        var statuses: [String: String] = [:]

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Git diff --name-status output format: "M\tfilename" or "A\tfilename"
            let components = trimmed.components(separatedBy: "\t")
            guard components.count == 2 else { continue }

            let status = components[0]
            let filename = components[1]
            let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()

            print("Processing line: status='\(status)', filename='\(filename)', extension='\(ext)', matches: \(imageExtensions.contains(ext))")

            if imageExtensions.contains(ext) {
                files.append(filename)
                statuses[filename] = status
            }
        }

        print("Final result - files: \(files), statuses: \(statuses)")
        return (files, statuses)
    } catch {
        print("Git command failed: \(error)")
        return ([], [:])
    }
}
