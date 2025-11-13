import Clocks
import ComposableArchitecture
@testable import Diffi
@testable import Git
import SwiftUI
import Testing
import XCTest

@Suite("ImageDiffFeature Tests")
struct ImageDiffFeatureTests {

    let modifiedFile = PickableFile(path: "test.png", status: .modified)
    let newFile = PickableFile(path: "test.png", status: .added)
    let currentImageURL: URL
    let tempDir: URL
    let previousImageData: Data
    let currentImageData: Data
    let previousImage: LoadedImage
    let currentImage: LoadedImage

    init() throws {
        tempDir = try makeTempDir()
        currentImageURL = tempDir.appendingPathComponent(modifiedFile.path)
        previousImageData = try createDummyImageData(color: .red, size: NSSize(width: 10, height: 10))
        currentImageData = try createDummyImageData(color: .blue, size: NSSize(width: 10, height: 10))
        previousImage = try ImageService.liveValue.loadImage(previousImageData).get()
        currentImage = try ImageService.liveValue.loadImage(currentImageData).get()
    }

    @MainActor
    @Test
    func defaultState() async {
        let store = TestStore(initialState: ImageDiffFeature.State(
            selectedFile: Shared(value: nil)
        )) {
            ImageDiffFeature()
        }

        #expect(store.state.viewMode == .sideBySide)
        #expect(store.state.blend == 0.5)
    }

    @MainActor
    @Test
    func setViewMode() async {
        let store = TestStore(initialState: ImageDiffFeature.State(
            selectedFile: Shared(value: nil)
        )) {
            ImageDiffFeature()
        }

        await store.send(.setViewMode(.onionSkin)) {
            $0.viewMode = .onionSkin
        }

        await store.send(.setViewMode(.sideBySide)) {
            $0.viewMode = .sideBySide
        }
    }

    @MainActor
    @Test
    func selectNextViewMode() async {
        let store = TestStore(initialState: ImageDiffFeature.State(
            selectedFile: Shared(value: nil)
        )) {
            ImageDiffFeature()
        }

        await store.send(.selectNextViewMode) {
            $0.viewMode = .onionSkin
        }

        await store.send(.selectNextViewMode) {
            $0.viewMode = .sideBySide
        }

        await store.send(.selectNextViewMode) {
            $0.viewMode = .onionSkin
        }
    }

    @MainActor
    @Test
    func setBlend_WithinBounds() async {
        let store = TestStore(initialState: ImageDiffFeature.State(
            selectedFile: Shared(value: nil)
        )) {
            ImageDiffFeature()
        }

        await store.send(.setBlend(0.7)) {
            $0.blend = 0.7
        }

        await store.send(.setBlend(0.0)) {
            $0.blend = 0.0
        }

        await store.send(.setBlend(1.0)) {
            $0.blend = 1.0
        }
    }

    @MainActor
    @Test
    func setBlend_ClampsToBounds() async {
        let store = TestStore(initialState: ImageDiffFeature.State(
            selectedFile: Shared(value: nil)
        )) {
            ImageDiffFeature()
        }

        await store.send(.setBlend(-0.5)) {
            $0.blend = 0.0
        }

        await store.send(.setBlend(1.5)) {
            $0.blend = 1.0
        }
    }

    // MARK: - File Selection Tests

    @MainActor
    @Test
    func selectedFileChanged_loadsPreviousAndCurrentImages() async throws {
        try currentImageData.write(to: currentImageURL)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var initialState = ImageDiffFeature.State(
            selectedFile: Shared(value: nil),
            repoFolder: Shared(value: tempDir)
        )
        initialState.currentVersionState = nil
        initialState.previousVersionState = nil

        let store = TestStore(initialState: initialState) {
            ImageDiffFeature()
        } withDependencies: {
            $0.gitService.showFile = { _, _, _ in .success(previousImageData) }
            $0.imageService.loadImage = { data in
                // Using the image we pre-load in the test means it will be equal when testing the effects below
                switch data {
                case previousImageData:
                        .success(previousImage)
                case currentImageData:
                        .success(currentImage)
                default:
                        .failure(.badData)
                }
            }
        }

        await store.send(
            .selectedFileChanged(
                repoFolder: tempDir,
                selectedFile: modifiedFile
            )
        ) {
            $0.previousVersionState = .loading
            $0.currentVersionState = .loading
        }

        await store.receive(\.cancelLoading)
        await store.receive(.imageLoaded(.current, .success(currentImage))) {
            $0.currentVersionState = .loaded(currentImage)
        }
        await store.receive(.imageLoaded(.previous, .success(previousImage))) {
            $0.previousVersionState = .loaded(previousImage)
        }
    }

    @MainActor
    @Test
    func selectedFileChanged_loadsOnlyCurrentImageForNewFile() async throws {
        try currentImageData.write(to: currentImageURL)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var initialState = ImageDiffFeature.State(
            selectedFile: Shared(value: nil),
            repoFolder: Shared(value: tempDir)
        )
        initialState.currentVersionState = nil
        initialState.previousVersionState = nil

        let store = TestStore(initialState: initialState) {
            ImageDiffFeature()
        } withDependencies: {
            $0.gitService.showFile = { _, _, _ in .success(previousImageData) }
            $0.imageService.loadImage = { data in
                // Using the image we pre-load in the test means it will be equal when testing the effects below
                switch data {
                case previousImageData:
                        .success(previousImage)
                case currentImageData:
                        .success(currentImage)
                default:
                        .failure(.badData)
                }
            }
        }

        await store.send(
            .selectedFileChanged(
                repoFolder: tempDir,
                selectedFile: newFile
            )
        ) {
            $0.previousVersionState = nil
            $0.currentVersionState = .loading
        }

        await store.receive(\.cancelLoading)
        await store.receive(.imageLoaded(.current, .success(currentImage))) {
            $0.currentVersionState = .loaded(currentImage)
        }
    }

    @MainActor
    @Test
    func selectedFileChanged_clearsStateForNilFile() async throws {
        try currentImageData.write(to: currentImageURL)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var initialState = ImageDiffFeature.State(
            selectedFile: Shared(value: modifiedFile),
            repoFolder: Shared(value: tempDir)
        )
        initialState.previousVersionState = .loaded(previousImage)
        initialState.currentVersionState = .loaded(currentImage)

        let store = TestStore(initialState: initialState) {
            ImageDiffFeature()
        }

        await store.send(
            .selectedFileChanged(
                repoFolder: tempDir,
                selectedFile: nil
            )
        ) {
            $0.previousVersionState = nil
            $0.currentVersionState = nil
        }

        await store.receive(.cancelLoading)
    }

    @MainActor
    @Test
    func selectedFileChanged_clearsStateForNonImageFile() async throws {
        let nonImagePickableFile = PickableFile(path: "test.txt", status: .modified)
        let fileURL = tempDir.appendingPathComponent(nonImagePickableFile.path)
        try "not an image".data(using: .utf8)!.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var initialState = ImageDiffFeature.State(
            selectedFile: Shared(value: modifiedFile),
            repoFolder: Shared(value: tempDir)
        )
        initialState.previousVersionState = .loaded(previousImage)
        initialState.currentVersionState = .loaded(currentImage)

        let store = TestStore(initialState: initialState) {
            ImageDiffFeature()
        }

        await store.send(
            .selectedFileChanged(
                repoFolder: tempDir,
                selectedFile: nonImagePickableFile
            )
        ) {
            $0.previousVersionState = nil
            $0.currentVersionState = nil
        }

        await store.receive(.cancelLoading)
    }

     @Test @MainActor
     func selectedFileChanged_handlesFailureToShowPreviousImage() async throws {
         try currentImageData.write(to: currentImageURL)
         defer { try? FileManager.default.removeItem(at: tempDir) }

         var initialState = ImageDiffFeature.State(
            selectedFile: Shared(value: nil),
            repoFolder: Shared(value: tempDir)
         )
         initialState.currentVersionState = nil
         initialState.previousVersionState = nil
    
         let store = TestStore(initialState: initialState) {
             ImageDiffFeature()
         } withDependencies: {
             $0.gitService.showFile = { _, _, _ in .failure(testError) }
             $0.imageService.loadImage = { data in
                 // Using the image we pre-load in the test means it will be equal when testing the effects below
                 switch data {
                 case previousImageData:
                         .success(previousImage)
                 case currentImageData:
                         .success(currentImage)
                 default:
                         .failure(.badData)
                 }
             }
         }
    
         await store.send(
            .selectedFileChanged(
                repoFolder: tempDir,
                selectedFile: modifiedFile
            )
         ) {
             $0.previousVersionState = .loading
             $0.currentVersionState = .loading
         }
    
         await store.receive(.cancelLoading)
         await store.receive(.imageLoaded(.current, .success(currentImage))) {
             $0.currentVersionState = .loaded(currentImage)
         }
         await store.receive(.imageLoaded(.previous, .failure(.gitError(testError)))) {
             $0.previousVersionState = .error(.gitError(testError))
         }
     }

    @Test @MainActor
    func selectedFileChanged_handlesFailureToLoadPreviousImage() async throws {
        try currentImageData.write(to: currentImageURL)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var initialState = ImageDiffFeature.State(
           selectedFile: Shared(value: nil),
           repoFolder: Shared(value: tempDir)
        )
        initialState.currentVersionState = nil
        initialState.previousVersionState = nil

        let store = TestStore(initialState: initialState) {
            ImageDiffFeature()
        } withDependencies: {
            $0.gitService.showFile = { _, _, _ in .success(previousImageData) }
            $0.imageService.loadImage = { data in
                // Using the image we pre-load in the test means it will be equal when testing the effects below
                switch data {
                case previousImageData:
                        .failure(.badData)
                case currentImageData:
                        .success(currentImage)
                default:
                        .failure(.badData)
                }
            }
        }

        await store.send(
           .selectedFileChanged(
               repoFolder: tempDir,
               selectedFile: modifiedFile
           )
        ) {
            $0.previousVersionState = .loading
            $0.currentVersionState = .loading
        }

        await store.receive(.cancelLoading)
        await store.receive(.imageLoaded(.current, .success(currentImage))) {
            $0.currentVersionState = .loaded(currentImage)
        }
        await store.receive(.imageLoaded(.previous, .failure(.badData))) {
            $0.previousVersionState = .error(.badData)
        }
    }

    @Test @MainActor
    func selectedFileChanged_handlesFailureToLoadCurrentImageFromData() async throws {
        try currentImageData.write(to: currentImageURL)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var initialState = ImageDiffFeature.State(
           selectedFile: Shared(value: nil),
           repoFolder: Shared(value: tempDir)
        )
        initialState.currentVersionState = nil
        initialState.previousVersionState = nil

        let store = TestStore(initialState: initialState) {
            ImageDiffFeature()
        } withDependencies: {
            $0.gitService.showFile = { _, _, _ in .success(previousImageData) }
            $0.imageService.loadImage = { data in
                switch data {
                case previousImageData:
                        .success(previousImage)
                case currentImageData:
                        .failure(.badData)
                default:
                        .failure(.badData)
                }
            }
        }

        await store.send(
           .selectedFileChanged(
               repoFolder: tempDir,
               selectedFile: modifiedFile
           )
        ) {
            $0.previousVersionState = .loading
            $0.currentVersionState = .loading
        }

        await store.receive(.cancelLoading)
        await store.receive(.imageLoaded(.current, .failure(.badData))) {
            $0.currentVersionState = .error(.badData)
        }
        await store.receive(.imageLoaded(.previous, .success(previousImage))) {
            $0.previousVersionState = .loaded(previousImage)
        }
    }
}

private let testError = GitError.testError
private extension GitError {
    static let testError = GitError.failedToOpenRepo(Clibgit2Error(code: .notFound))
}
