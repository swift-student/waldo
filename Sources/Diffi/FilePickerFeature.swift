import ComposableArchitecture
import Git
import SwiftUI

@Reducer
public struct FilePickerFeature {
    @ObservableState
    public struct State: Equatable {
        var files: [PickableFile] = []
        @Shared var selectedFile: PickableFile?

        public init(selectedFile: Shared<PickableFile?> = Shared(value: nil)) {
            _selectedFile = selectedFile
        }
    }

    public enum Action: Equatable {
        case navigateUp
        case navigateDown
        case userSelectedFile(PickableFile?)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .navigateUp:
                guard let selectedFile = state.selectedFile,
                      let index = state.files.firstIndex(of: selectedFile)
                else {
                    return .none
                }

                let newSelection = state.files[clamped: index - 1]
                guard newSelection != state.selectedFile else {
                    return .none
                }

                state.$selectedFile.withLock { $0 = newSelection }
                return .none

            case .navigateDown:
                guard let selectedFile = state.selectedFile,
                      let index = state.files.firstIndex(of: selectedFile)
                else {
                    return .none
                }

                let newSelection = state.files[clamped: index + 1]
                guard newSelection != state.selectedFile else {
                    return .none
                }

                state.$selectedFile.withLock { $0 = newSelection }
                return .none

            case let .userSelectedFile(file):
                state.$selectedFile.withLock { $0 = file }
                return .none
            }
        }
    }
}

// TODO: Test these

extension Int {
    func clamped(to range: Range<Int>) -> Int {
        return Swift.max(range.lowerBound, Swift.min(self, range.upperBound - 1))
    }
}

extension MutableCollection where Index == Int {
    subscript(clamped index: Int) -> Element {
        get {
            self[index.clamped(to: startIndex ..< endIndex)]
        }
        set {
            self[index.clamped(to: startIndex ..< endIndex)] = newValue
        }
    }
}
