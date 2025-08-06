import Combine
import ComposableArchitecture
import Foundation
import Git
import SwiftUI

@Reducer
public struct ImageDiffFeature {
    @ObservableState
    public struct State: Equatable {
        @SharedReader var selectedFile: PickableFile?
        @SharedReader var repoFolder: URL?
        var previousVersionData: Data?
        var currentVersionData: Data?
        var isLoading: Bool = false
        var error: GitError?

        init(
            selectedFile: Shared<PickableFile?>,
            repoFolder: Shared<URL?> = Shared(value: nil)
        ) {
            _selectedFile = SharedReader(selectedFile)
            _repoFolder = SharedReader(repoFolder)
        }
    }

    public enum Action: Equatable {
        case onAppear
        case selectedFileChanged(repoFolder: URL?, selectedFile: PickableFile?)
        case previousVersionLoaded(Result<Data, GitError>)
        case currentVersionLoaded(Result<Data, GitError>)
        case clearError
    }

    @Dependency(\.gitService) var gitService

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .publisher {
                    Publishers.CombineLatest(
                        state.$repoFolder.publisher,
                        state.$selectedFile.publisher
                    ).map(Action.selectedFileChanged)
                }

            case let .selectedFileChanged(repoFolder, selectedFile):
                guard let repoFolder, let selectedFile, selectedFile.isImageFile else {
                    state.previousVersionData = nil
                    state.currentVersionData = nil
                    state.isLoading = false
                    return .none
                }

                state.isLoading = true
                state.error = nil
                state.previousVersionData = nil
                state.currentVersionData = nil

                return .run { [gitService] send in
                    // Load current version (from working directory)
                    async let currentTask: () = loadCurrentVersion(repoFolder: repoFolder, filePath: selectedFile.path, send: send)

                    // Load previous version only if file is modified
                    if selectedFile.status == .modified {
                        async let previousTask: () = loadPreviousVersion(repoFolder: repoFolder, filePath: selectedFile.path, gitService: gitService, send: send)
                        await currentTask
                        await previousTask
                    } else {
                        await currentTask
                    }
                }

            case let .previousVersionLoaded(result):
                state.isLoading = false
                switch result {
                case let .success(data):
                    state.previousVersionData = data
                case let .failure(error):
                    state.error = error
                }
                return .none

            case let .currentVersionLoaded(result):
                state.isLoading = false
                switch result {
                case let .success(data):
                    state.currentVersionData = data
                case let .failure(error):
                    state.error = error
                }
                return .none
            case .clearError:
                state.error = nil
                return .none
            }
        }
    }

    private func loadCurrentVersion(repoFolder: URL, filePath: String, send: Send<Action>) async {
        let fileURL = repoFolder.appendingPathComponent(filePath)
        do {
            let data = try Data(contentsOf: fileURL)
            await send(.currentVersionLoaded(.success(data)))
        } catch {
            await send(.currentVersionLoaded(.failure(.fileSystemError(error.localizedDescription))))
        }
    }

    private func loadPreviousVersion(repoFolder: URL, filePath: String, gitService: GitService, send: Send<Action>) async {
        let result = gitService.showFile(repoFolder, "HEAD", filePath)
        await send(.previousVersionLoaded(result))
    }
}
