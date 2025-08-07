import ComposableArchitecture
import Foundation
import Git
import PrintDebug
import SwiftUI

@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        @Shared var selectedFile: PickableFile?
        @Shared var repoFolder: URL?
        var filePickerFeature: FilePickerFeature.State
        var folderPickerFeature = FolderPickerFeature.State()
        var diffFeature: DiffFeature.State
        var imageDiffFeature: ImageDiffFeature.State

        public init() {
            _selectedFile = Shared(value: nil)
            _repoFolder = Shared(value: nil)
            filePickerFeature = FilePickerFeature.State(selectedFile: _selectedFile)
            diffFeature = DiffFeature.State(repoFolder: _repoFolder)
            imageDiffFeature = ImageDiffFeature.State(selectedFile: _selectedFile, repoFolder: _repoFolder)
        }
    }

    public enum Action: Equatable {
        case filePickerFeature(FilePickerFeature.Action)
        case folderPickerFeature(FolderPickerFeature.Action)
        case diffFeature(DiffFeature.Action)
        case imageDiffFeature(ImageDiffFeature.Action)
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
        Scope(state: \.imageDiffFeature, action: \.imageDiffFeature) {
            ImageDiffFeature()
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

                state.$repoFolder.withLock { $0 = folder }

                return .send(.diffFeature(.startDiffPolling))

            case let .folderPickerFeature(.failurePickingFolder(error)):
                // TODO: Handle failure
                print(error)
                return .none

            case .folderPickerFeature:
                return .none

            case let .diffFeature(.diffResult(.success(files))):
                let imageFiles = files.filter { $0.isImageFile }
                
                // Check if selected file is still in the diff results
                if let selectedFile = state.selectedFile,
                   !imageFiles.contains(selectedFile) {
                    state.$selectedFile.withLock { $0 = nil }
                }
                
                state.filePickerFeature.files = imageFiles
                return .none

            case .diffFeature:
                return .none

            case .imageDiffFeature:
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
