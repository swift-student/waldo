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
        self.id = path
    }
    
    public init(from fileChange: Git.Diff.FileChange) {
        self.path = fileChange.path
        self.status = fileChange.status
        self.id = fileChange.id
    }
}

@Reducer
public struct FilePickerFeature {
    @ObservableState
    public struct State: Equatable {
        public var files: [PickableFile]
        public var selectedFile: PickableFile?
        
        public init(files: [PickableFile] = [], selectedFile: PickableFile? = nil) {
            self.files = files
            self.selectedFile = selectedFile
        }
    }
    
    public enum Action {
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
                
                let newIndex = index > 0 ? index - 1 : 0
                state.selectedFile = state.files[newIndex]
                return .none
                
            case .navigateDown:
                guard let selectedFile = state.selectedFile,
                      let index = state.files.firstIndex(of: selectedFile)
                else {
                    return .none
                }
                
                let newIndex = index < state.files.count - 1 ? index + 1 : state.files.count - 1
                state.selectedFile = state.files[newIndex]
                return .none
                
            case let .userSelectedFile(file):
                state.selectedFile = file
                return .none
            }
        }
    }
}