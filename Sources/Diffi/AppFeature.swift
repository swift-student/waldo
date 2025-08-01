import ComposableArchitecture
import Foundation
import Git
import PrintDebug
import SwiftUI

@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        var filePickerFeature = FilePickerFeature.State()
        var folderPickerFeature = FolderPickerFeature.State()
        var diffFeature = DiffFeature.State()
    }

    public enum Action: Equatable {
        case filePickerFeature(FilePickerFeature.Action)
        case folderPickerFeature(FolderPickerFeature.Action)
        case diffFeature(DiffFeature.Action)
    }

    @Dependency(\.fileService.fileExists) var fileExists
    @Dependency(\.gitService) var gitService

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
        Scope(state: \.diffFeature, action: \.diffFeature) {
            DiffFeature()
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

                state.diffFeature.repoFolder = folder

                return .send(.diffFeature(.startDiffPolling))

            case let .folderPickerFeature(.failurePickingFolder(error)):
                // TODO: Handle failure
                print(error)
                return .none

            case .folderPickerFeature:
                return .none

            case let .diffFeature(.diffResult(.success(files))):
                state.filePickerFeature.files = files
                return .none

            case .diffFeature:
                return .none
            }
        }
    }
}

public extension AppFeature.State {
    static func make() -> Self {
        .init()
    }
}
