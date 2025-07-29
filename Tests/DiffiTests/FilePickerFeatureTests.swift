import ComposableArchitecture
@testable import Diffi
import Foundation
import Git
import Testing

@MainActor
struct FilePickerFeatureTests {
    
    // Helper to create mock file changes
    private func mockFileChange(path: String) -> PickableFile {
        return PickableFile(path: path, status: .modified)
    }
    
    @Test func initialState_default() {
        let store = TestStore(initialState: FilePickerFeature.State()) {
            FilePickerFeature()
        }
        
        #expect(store.state.files.isEmpty)
        #expect(store.state.selectedFile == nil)
    }
    
    @Test func initialState_withFiles() {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift")
        ]
        let selectedFile = files[0]
        
        let store = TestStore(
            initialState: FilePickerFeature.State(files: files, selectedFile: selectedFile)
        ) {
            FilePickerFeature()
        }
        
        #expect(store.state.files == files)
        #expect(store.state.selectedFile == selectedFile)
    }
    
    @Test func navigateUp_noSelection() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift")
        ]
        
        let store = TestStore(
            initialState: FilePickerFeature.State(files: files, selectedFile: nil)
        ) {
            FilePickerFeature()
        }
        
        await store.send(.navigateUp)
    }
    
    @Test func navigateUp_fromFirstFile() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift"),
            mockFileChange(path: "file3.swift")
        ]
        
        let store = TestStore(
            initialState: FilePickerFeature.State(files: files, selectedFile: files[0])
        ) {
            FilePickerFeature()
        }
        
        // Should stay at first file - no state change expected
        await store.send(.navigateUp)
    }
    
    @Test func navigateUp_fromMiddleFile() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift"),
            mockFileChange(path: "file3.swift")
        ]
        
        let store = TestStore(
            initialState: FilePickerFeature.State(files: files, selectedFile: files[1])
        ) {
            FilePickerFeature()
        }
        
        await store.send(.navigateUp) {
            $0.selectedFile = files[0] // Should move to previous file
        }
    }
    
    @Test func navigateDown_noSelection() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift")
        ]
        
        let store = TestStore(
            initialState: FilePickerFeature.State(files: files, selectedFile: nil)
        ) {
            FilePickerFeature()
        }
        
        await store.send(.navigateDown)
    }
    
    @Test func navigateDown_fromLastFile() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift"),
            mockFileChange(path: "file3.swift")
        ]
        
        let store = TestStore(
            initialState: FilePickerFeature.State(files: files, selectedFile: files[2])
        ) {
            FilePickerFeature()
        }
        
        // Should stay at last file - no state change expected
        await store.send(.navigateDown)
    }
    
    @Test func navigateDown_fromMiddleFile() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift"),
            mockFileChange(path: "file3.swift")
        ]
        
        let store = TestStore(
            initialState: FilePickerFeature.State(files: files, selectedFile: files[1])
        ) {
            FilePickerFeature()
        }
        
        await store.send(.navigateDown) {
            $0.selectedFile = files[2] // Should move to next file
        }
    }
    
    @Test func userSelectedFile_withValidFile() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift")
        ]
        
        let store = TestStore(
            initialState: FilePickerFeature.State(files: files, selectedFile: nil)
        ) {
            FilePickerFeature()
        }
        
        await store.send(.userSelectedFile(files[1])) {
            $0.selectedFile = files[1]
        }
    }
    
    @Test func userSelectedFile_withNil() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift")
        ]
        
        let store = TestStore(
            initialState: FilePickerFeature.State(files: files, selectedFile: files[0])
        ) {
            FilePickerFeature()
        }
        
        await store.send(.userSelectedFile(nil)) {
            $0.selectedFile = nil
        }
    }
    
    @Test func navigation_withEmptyFiles() async {
        let store = TestStore(
            initialState: FilePickerFeature.State(files: [], selectedFile: nil)
        ) {
            FilePickerFeature()
        }
        
        await store.send(.navigateUp)
        await store.send(.navigateDown)
    }
    
    @Test func navigation_withSingleFile() async {
        let files = [mockFileChange(path: "file1.swift")]
        
        let store = TestStore(
            initialState: FilePickerFeature.State(files: files, selectedFile: files[0])
        ) {
            FilePickerFeature()
        }
        
        // Should stay at same file - no state changes expected
        await store.send(.navigateUp)
        await store.send(.navigateDown)
    }
}