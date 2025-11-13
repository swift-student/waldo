import Combine
import ComposableArchitecture
import Foundation
import Git
import SwiftUI

public struct LoadedImage: Equatable {
    public let image: Image
    public let size: CGSize
}

public enum ImageLoadState: Equatable {
    case loading
    case loaded(LoadedImage)
    case error(ImageDiffError)
    case deleted
}

public enum ImageVersionType: Equatable, Hashable {
    case current
    case previous
}

public enum ImageDiffViewMode: Equatable, CaseIterable {
    case sideBySide
    case onionSkin
}

private enum CancellableID {
    case imageLoading
}

@Reducer
public struct ImageDiffFeature {
    @ObservableState
    public struct State: Equatable {
        @SharedReader var selectedFile: PickableFile?
        @SharedReader var repoFolder: URL?
        var previousVersionState: ImageLoadState? = .loading
        var currentVersionState: ImageLoadState? = .loading
        var viewMode: ImageDiffViewMode = .sideBySide

        /// The blend amount between the previous and current versions, where 0.0 is all previous, and 1.0 is all current.
        /// Not applicable to `sideBySide` mode
        var blend: Double = 0.5

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
        case imageLoaded(ImageVersionType, Result<LoadedImage, ImageDiffError>)
        case cancelLoading
        case setViewMode(ImageDiffViewMode)
        case selectNextViewMode
        case setBlend(Double)
    }

    @Dependency(\.gitService) var gitService
    @Dependency(\.imageService) var imageService

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

                if selectedFile.status == .deleted {
                    state.currentVersionState = .deleted
                    state.previousVersionState = .loading

                    return .merge(
                        cancelEffect,
                        .run { [gitService] send in
                            await loadImageForVersion(
                                .previous,
                                repoFolder: repoFolder,
                                filePath: selectedFile.path,
                                gitService: gitService,
                                send: send
                            )
                        }
                        .cancellable(id: CancellableID.imageLoading)
                    )
                }

                let shouldLoadPreviousVersion = selectedFile.status == .modified || selectedFile.status == .renamed

                state.currentVersionState = .loading
                state.previousVersionState = shouldLoadPreviousVersion ? .loading : nil

                return .merge(
                    cancelEffect,
                    .run { [gitService] send in
                        await loadImageForVersion(
                            .current,
                            repoFolder: repoFolder,
                            filePath: selectedFile.path,
                            gitService: gitService,
                            send: send
                        )
                    }
                    .cancellable(id: CancellableID.imageLoading),
                    .run { [gitService] send in
                        guard shouldLoadPreviousVersion else { return }
                        await loadImageForVersion(
                            .previous,
                            repoFolder: repoFolder,
                            filePath: selectedFile.path,
                            gitService: gitService,
                            send: send
                        )
                    }
                    .cancellable(id: CancellableID.imageLoading)
                )

            case let .imageLoaded(version, result):
                switch version {
                case .current:
                    switch result {
                    case let .success(loadedImage):
                        state.currentVersionState = .loaded(loadedImage)
                    case let .failure(error):
                        state.currentVersionState = .error(error)
                    }
                case .previous:
                    switch result {
                    case let .success(loadedImage):
                        state.previousVersionState = .loaded(loadedImage)
                    case let .failure(error):
                        state.previousVersionState = .error(error)
                    }
                }
                return .none

            case .cancelLoading:
                return .cancel(id: CancellableID.imageLoading)

            case let .setViewMode(mode):
                state.viewMode = mode
                return .none

            case .selectNextViewMode:
                let currentMode = state.viewMode
                let allModes = ImageDiffViewMode.allCases
                guard let currentIndex = allModes.firstIndex(of: currentMode) else { return .none }

                let nextIndex = (currentIndex + 1) % allModes.count
                state.viewMode = allModes[nextIndex]
                return .none

            case let .setBlend(blend):
                state.blend = max(0.0, min(1.0, blend))
                return .none
            }
        }
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
                case let .success(gitData):
                    data = gitData
                case let .failure(error):
                    await send(.imageLoaded(version, .failure(.gitError(error))))
                    return
                }
            }

            switch imageService.loadImage(data) {
            case .success(let loadedImage):
                await send(.imageLoaded(version, .success(loadedImage)))
            case .failure:
                await send(.imageLoaded(version, .failure(.badData)))
            }
        } catch {
            await send(.imageLoaded(version, .failure(.fileSystemError(error.localizedDescription))))
        }
    }
}

public enum ImageDiffError: Error, Equatable, CustomDebugStringConvertible {
    case badData
    case fileSystemError(String)
    case gitError(GitError)

    public var debugDescription: String {
        switch self {
        case .badData:
            "Unable to load image from data"
        case .fileSystemError(let errorDescription):
            errorDescription
        case .gitError(let error):
            error.debugDescription
        }
    }
}
