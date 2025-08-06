import Combine
import ComposableArchitecture
import Foundation
import Git
import SwiftUI

public enum ImageLoadState: Equatable {
    case loading
    case loaded(Image)
    case error(GitError)
}

public enum ImageVersionType: Equatable, Hashable {
    case current
    case previous
}

private struct ImageLoadingCancelID: Hashable {}

@Reducer
public struct ImageDiffFeature {
    @ObservableState
    public struct State: Equatable {
        @SharedReader var selectedFile: PickableFile?
        @SharedReader var repoFolder: URL?
        var previousVersionState: ImageLoadState? = .loading
        var currentVersionState: ImageLoadState? = .loading

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
        case startImageLoading(ImageVersionType)
        case imageLoaded(ImageVersionType, Result<Image, GitError>)
        case cancelLoading
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
                let cancelEffect: Effect<Action> = .send(.cancelLoading)
                
                guard let repoFolder, let selectedFile, selectedFile.isImageFile else {
                    state.previousVersionState = nil
                    state.currentVersionState = nil
                    return cancelEffect
                }

                let shouldLoadPreviousVersion = selectedFile.status == .modified

                state.currentVersionState = .loading

                if shouldLoadPreviousVersion {
                    state.previousVersionState = .loading
                } else {
                    state.previousVersionState = nil
                }

                return .merge(
                    cancelEffect,
                    .run { [gitService] send in
                        await send(.startImageLoading(.current))
                        async let currentTask: () = loadImageForVersion(
                            .current,
                            repoFolder: repoFolder,
                            filePath: selectedFile.path,
                            gitService: gitService,
                            send: send
                        )
                        
                        if shouldLoadPreviousVersion {
                            await send(.startImageLoading(.previous))
                            async let previousTask: () = loadImageForVersion(
                                .previous,
                                repoFolder: repoFolder,
                                filePath: selectedFile.path,
                                gitService: gitService,
                                send: send
                            )
                            
                            await currentTask
                            await previousTask
                        } else {
                            await currentTask
                        }
                    }
                    .cancellable(id: ImageLoadingCancelID())
                )
                
            case let .startImageLoading(version):
                // Set specific version to loading state
                switch version {
                case .current:
                    state.currentVersionState = .loading
                case .previous:
                    state.previousVersionState = .loading
                }
                return .none

            case let .imageLoaded(version, result):
                switch version {
                case .current:
                    switch result {
                    case let .success(image):
                        state.currentVersionState = .loaded(image)
                    case let .failure(error):
                        state.currentVersionState = .error(error)
                    }
                case .previous:
                    switch result {
                    case let .success(image):
                        state.previousVersionState = .loaded(image)
                    case let .failure(error):
                        state.previousVersionState = .error(error)
                    }
                }
                return .none
                
            case .cancelLoading:
                return .cancel(id: ImageLoadingCancelID())
            }
        }
    }

    private func convertDataToImage(_ data: Data) -> Image? {
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
    }
    
    private func loadImageForVersion(
        _ version: ImageVersionType,
        repoFolder: URL,
        filePath: String,
        gitService: GitService,
        send: Send<Action>
    ) async {
        do {
            let data: Data
            
            switch version {
            case .current:
                let fileURL = repoFolder.appendingPathComponent(filePath)
                data = try Data(contentsOf: fileURL)
            case .previous:
                let result = gitService.showFile(repoFolder, "HEAD", filePath)
                switch result {
                case .success(let gitData):
                    data = gitData
                case .failure(let error):
                    await send(.imageLoaded(version, .failure(error)))
                    return
                }
            }
            
            guard let image = convertDataToImage(data) else {
                await send(.imageLoaded(version, .failure(.fileSystemError("Could not create image from data"))))
                return
            }
            
            await send(.imageLoaded(version, .success(image)))
        } catch {
            await send(.imageLoaded(version, .failure(.fileSystemError(error.localizedDescription))))
        }
    }
}
