import ComposableArchitecture
import SwiftUI

@Reducer
public struct FolderPickerFeature {
    @ObservableState
    public struct State: Equatable {
        public var showingFolderPicker = false

        public init() {}
    }

    public enum Action {
        case showingFolderPickerChanged(Bool)
        case userPickedFolder(URL)
        case failurePickingFolder(Error)
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
