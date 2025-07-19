import ComposableArchitecture
import SwiftUI


@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public init() {}
        var showingFolderPicker = false
        var repoFolder: URL?
    }

    public enum Action {
        case showingFolderPickerChanged(Bool)
        case userPickedFolder(URL)
        case failurePickingFolder(Error)
    }

    @Dependency(\.fileService.fileExists) var fileExists

    public init() {}

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
                return .none
            case let .failurePickingFolder(error):
                // TODO: Handle failure
                print(error)
                return .none
            }
        }
    }
}
