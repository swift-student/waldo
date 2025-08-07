import ComposableArchitecture
@testable import Diffi
import Foundation
import Git
import Testing

@MainActor
struct FilePickerFeatureTests {
    private func mockFileChange(path: String) -> PickableFile {
        return PickableFile(path: path, status: .modified)
    }

    @Test
    func initialState_default() {
        let store = TestStore(initialState: FilePickerFeature.State(selectedFile: Shared(value: nil))) {
            FilePickerFeature()
        }

        #expect(store.state.files.isEmpty)
        #expect(store.state.selectedFile == nil)
    }

    @Test
    func initialState_withFiles() {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift"),
        ]
        let selectedFile = files[0]

        let state = FilePickerFeature.State(files: files, selectedFile: Shared(value: selectedFile))

        let store = TestStore(initialState: state) {
            FilePickerFeature()
        }

        #expect(store.state.files == files)
        #expect(store.state.selectedFile == selectedFile)
    }

    @Test
    func navigateUp_noSelection() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift"),
        ]

        let state = FilePickerFeature.State(files: files)

        let store = TestStore(initialState: state) {
            FilePickerFeature()
        }

        await store.send(.navigateUp)
    }

    @Test
    func navigateUp_fromFirstFile() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift"),
            mockFileChange(path: "file3.swift"),
        ]

        let selectedFile = Shared<PickableFile?>(value: files[0])
        let state = FilePickerFeature.State(files: files, selectedFile: selectedFile)

        let store = TestStore(initialState: state) {
            FilePickerFeature()
        }

        // Should stay at first file - no state change expected
        await store.send(.navigateUp)
    }

    @Test
    func navigateUp_fromMiddleFile() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift"),
            mockFileChange(path: "file3.swift"),
        ]

        let selectedFile = files[1]
        let state = FilePickerFeature.State(files: files, selectedFile: Shared(value: selectedFile))

        let store = TestStore(initialState: state) {
            FilePickerFeature()
        }

        await store.send(.navigateUp) {
            $0.$selectedFile.withLock { $0 = files[0] }
        }
    }

    @Test
    func navigateDown_noSelection() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift"),
        ]

        let state = FilePickerFeature.State(files: files)

        let store = TestStore(initialState: state) {
            FilePickerFeature()
        }

        await store.send(.navigateDown)
    }

    @Test
    func navigateDown_fromLastFile() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift"),
            mockFileChange(path: "file3.swift"),
        ]

        let selectedFile = files[2]
        let state = FilePickerFeature.State(files: files, selectedFile: Shared(value: selectedFile))

        let store = TestStore(initialState: state) {
            FilePickerFeature()
        }

        // Should stay at last file - no state change expected
        await store.send(.navigateDown)
    }

    @Test
    func navigateDown_fromMiddleFile() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift"),
            mockFileChange(path: "file3.swift"),
        ]

        let selectedFile = files[1]
        let state = FilePickerFeature.State(files: files, selectedFile: Shared(value: selectedFile))

        let store = TestStore(initialState: state) {
            FilePickerFeature()
        }

        await store.send(.navigateDown) {
            $0.$selectedFile.withLock { $0 = files[2] }
        }
    }

    @Test
    func userSelectedFile_withValidFile() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift"),
        ]

        let state = FilePickerFeature.State(files: files)

        let store = TestStore(initialState: state) {
            FilePickerFeature()
        }

        await store.send(.userSelectedFile(files[1])) {
            $0.$selectedFile.withLock { $0 = files[1] }
        }
    }

    @Test
    func userSelectedFile_withNil() async {
        let files = [
            mockFileChange(path: "file1.swift"),
            mockFileChange(path: "file2.swift"),
        ]

        let selectedFile = files[0]
        let state = FilePickerFeature.State(files: files, selectedFile: Shared(value: selectedFile))

        let store = TestStore(initialState: state) {
            FilePickerFeature()
        }

        await store.send(.userSelectedFile(nil)) {
            $0.$selectedFile.withLock { $0 = nil }
        }
    }

    @Test
    func navigation_withEmptyFiles() async {
        let selectedFile = Shared<PickableFile?>(value: nil)
        let store = TestStore(
            initialState: FilePickerFeature.State(selectedFile: selectedFile)
        ) {
            FilePickerFeature()
        }

        await store.send(.navigateUp)
        await store.send(.navigateDown)
    }

    @Test
    func navigation_withSingleFile() async {
        let files = [mockFileChange(path: "file1.swift")]

        let selectedFile = files[0]
        let state = FilePickerFeature.State(files: files, selectedFile: Shared(value: selectedFile))

        let store = TestStore(initialState: state) {
            FilePickerFeature()
        }

        // Should stay at same file - no state changes expected
        await store.send(.navigateUp)
        await store.send(.navigateDown)
    }
}
