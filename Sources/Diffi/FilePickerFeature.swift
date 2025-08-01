import ComposableArchitecture
import Git
import SwiftUI

public struct PickableFile: Hashable, Equatable, Identifiable {
    public let id: String
    public let path: String
    public let status: Git.Diff.Status

    public init(path: String, status: Git.Diff.Status) {
        self.path = path
        self.status = status
        id = path
    }

    public init(from fileChange: Git.Diff.FileChange) {
        path = fileChange.path
        status = fileChange.status
        id = fileChange.id
    }
}

@Reducer
public struct FilePickerFeature {
    @ObservableState
    public struct State: Equatable {
        var files: [PickableFile] = []
        var selectedFile: PickableFile?
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

                state.selectedFile = state.files[clamped: index - 1]
                return .none

            case .navigateDown:
                guard let selectedFile = state.selectedFile,
                      let index = state.files.firstIndex(of: selectedFile)
                else {
                    return .none
                }

                state.selectedFile = state.files[clamped: index + 1]
                return .none

            case let .userSelectedFile(file):
                state.selectedFile = file
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
