import ComposableArchitecture
import Git
import PrintDebug
import SwiftUI

@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public init() {}
        var showingFolderPicker = false
        var repoFolder: URL?
        var fileChanges: [Git.Diff.FileChange]?
    }

    public enum Action {
        case showingFolderPickerChanged(Bool)
        case userPickedFolder(URL)
        case failurePickingFolder(Error)
    }

    @Dependency(\.fileService.fileExists) var fileExists

    public init() {
        // TODO: Where should this go and what should we do if it doesn't initialize. Also need to shutdown.
        try? Git.initialize()
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .showingFolderPickerChanged(shouldShow):
                state.showingFolderPicker = shouldShow
                return .none
            case let .userPickedFolder(folder):
                guard folder.startAccessingSecurityScopedResource() else {
                    // TODO: Handle this
                    return .none
                }
                defer { folder.stopAccessingSecurityScopedResource() }

                let gitPath = folder.appendingPathComponent(".git")
                var isDirectory: ObjCBool = false
                guard fileExists(gitPath.path(), &isDirectory) else {
                    // TODO: Handle this
                    return .none
                }

                state.repoFolder = folder

                // We need to do a git diff once we have a folder
                // Really that needs to happen on a timer, but let's start with doing it here
                let repo = try? Git.Repo(url: folder)
                state.fileChanges = try? repo?.diffNameStatusWorkingTree()

                return .none
            case let .failurePickingFolder(error):
                // TODO: Handle failure
                print(error)
                return .none
            }
        }
    }
}
