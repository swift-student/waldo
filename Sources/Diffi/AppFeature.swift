import SwiftUI
import ComposableArchitecture
import Foundation
import Clocks

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var repositoryPath: URL?
        var changedImageFiles: [String] = []
        var selectedFile: String?
        var showingFolderPicker = false
    }
    
    enum Action {
        case folderPickerButtonTapped
        case folderSelected(URL)
        case folderPickerDismissed
        case timerTicked
        case gitFilesLoaded([String])
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
                    let files = await getChangedImageFiles(at: repoPath)
                    await send(.gitFilesLoaded(files))
                }
                
            case let .gitFilesLoaded(files):
                state.changedImageFiles = files
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

private func getChangedImageFiles(at repoPath: URL) async -> [String] {
    let task = Process()
    task.currentDirectoryURL = repoPath
    task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    task.arguments = ["diff", "--name-only", "--diff-filter=M"]
    
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
        let result = output.components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                let ext = URL(fileURLWithPath: trimmed).pathExtension.lowercased()
                print("Processing line: '\(trimmed)', extension: '\(ext)', matches: \(imageExtensions.contains(ext))")
                return imageExtensions.contains(ext) ? trimmed : nil
            }
        
        print("Final result: \(result)")
        return result
    } catch {
        print("Git command failed: \(error)")
        return []
    }
}