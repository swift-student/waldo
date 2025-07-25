import ComposableArchitecture
import Git
import SwiftUI

@Reducer
public struct FilePickerFeature {
    @ObservableState
    public struct State: Equatable {
        public var files: [Git.Diff.FileChange]
        public var selectedFile: Git.Diff.FileChange?
        
        public init(files: [Git.Diff.FileChange] = [], selectedFile: Git.Diff.FileChange? = nil) {
            self.files = files
            self.selectedFile = selectedFile
        }
    }
    
    public enum Action {
        case navigateUp
        case navigateDown
        case userSelectedFile(Git.Diff.FileChange?)
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