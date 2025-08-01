import ComposableArchitecture
@testable import Diffi
import Foundation
import Testing

@MainActor
struct FolderPickerFeatureTests {
    
    @Test func initialState() {
        let store = TestStore(initialState: FolderPickerFeature.State()) {
            FolderPickerFeature()
        }
        
        #expect(store.state.showingFolderPicker == false)
    }
    
    @Test func showingFolderPickerChanged() async {
        let store = TestStore(initialState: FolderPickerFeature.State()) {
            FolderPickerFeature()
        }
        
        await store.send(.showingFolderPickerChanged(true)) {
            $0.showingFolderPicker = true
        }

        await store.send(.showingFolderPickerChanged(false)) {
            $0.showingFolderPicker = false
        }
    }

    @Test func userPickedFolder_delegatesToParent() async {
        let store = TestStore(initialState: FolderPickerFeature.State()) {
            FolderPickerFeature()
        }
        
        let testURL = URL(fileURLWithPath: "/test/path")
        await store.send(.userPickedFolder(testURL))
    }
    
    @Test func failurePickingFolder_delegatesToParent() async {
        let store = TestStore(initialState: FolderPickerFeature.State()) {
            FolderPickerFeature()
        }
        
        struct TestError: Error {}
        await store.send(.failurePickingFolder(FolderPickerFeature.PickerError(TestError())))
    }
}
