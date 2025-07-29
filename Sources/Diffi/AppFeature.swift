import ComposableArchitecture
import Git
import PrintDebug
import SwiftUI

@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public init() {}
        var filePickerFeature = FilePickerFeature.State()
        var folderPickerFeature = FolderPickerFeature.State()
        var repoFolder: URL?
    }

    public enum Action {
        case filePickerFeature(FilePickerFeature.Action)
        case folderPickerFeature(FolderPickerFeature.Action)
    }

    @Dependency(\.fileService.fileExists) var fileExists

    public init() {
        // TODO: Where should this go and what should we do if it doesn't initialize. Also need to shutdown.
        try? Git.initialize()
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.filePickerFeature, action: \.filePickerFeature) {
            FilePickerFeature()
        }
        Scope(state: \.folderPickerFeature, action: \.folderPickerFeature) {
            FolderPickerFeature()
        }
        Reduce { state, action in
            switch action {
            case .filePickerFeature:
                return .none
            case let .folderPickerFeature(.userPickedFolder(folder)):
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
                let fileChanges = (try? repo?.diffNameStatusWorkingTree()) ?? []
                state.filePickerFeature.files = fileChanges.map { PickableFile(from: $0) }

                return .none
            case let .folderPickerFeature(.failurePickingFolder(error)):
                // TODO: Handle failure
                print(error)
                return .none
            case .folderPickerFeature:
                return .none
            }
        }
    }
}
