import ComposableArchitecture
import SwiftUI

@Reducer
public struct FolderPickerFeature {
    public enum PickerError: Error, Equatable {
        case folderPickingFailed(String)
        
        init(_ error: Error) {
            self = .folderPickingFailed(error.localizedDescription)
        }
    }
    @ObservableState
    public struct State: Equatable {
        public var showingFolderPicker = false

        public init() {}
    }

    public enum Action: Equatable {
        case showingFolderPickerChanged(Bool)
        case userPickedFolder(URL)
        case failurePickingFolder(PickerError)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .showingFolderPickerChanged(shouldShow):
                state.showingFolderPicker = shouldShow
                return .none
            case .userPickedFolder:
                // Parent will handle the folder processing
                return .none
            case .failurePickingFolder:
                // Parent will handle the error
                return .none
            }
        }
    }
}
