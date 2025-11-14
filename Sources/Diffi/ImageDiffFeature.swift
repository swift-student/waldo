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

    var blendable: Bool {
        switch self {
        case .onionSkin:
            return true
        case .sideBySide:
            return false
        }
    }
}

private enum CancellableID {
    case imageLoading
    case autoBlend
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
        var isAutoBlending = false

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
        case toggleAutoBlend
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
                state.isAutoBlending = false
                let cancelEffect: Effect<Action> = .merge(
                    .send(.cancelLoading),
                    .cancel(id: CancellableID.autoBlend)
                )

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
                if !mode.blendable, state.isAutoBlending {
                    state.isAutoBlending = false
                    return .cancel(id: CancellableID.autoBlend)
                }
                return .none

            case .selectNextViewMode:
                let currentMode = state.viewMode
                let allModes = ImageDiffViewMode.allCases
                guard let currentIndex = allModes.firstIndex(of: currentMode) else { return .none }

                let nextIndex = (currentIndex + 1) % allModes.count
                let nextMode = allModes[nextIndex]
                // TODO: Don't send here, it is discouraged
                // Use a func instead to share logic
                return .send(.setViewMode(nextMode))

            case let .setBlend(blend):
                state.blend = max(0.0, min(1.0, blend))
                return .none

            case .toggleAutoBlend:
                // TODO: Extract/test
                guard state.viewMode.blendable else { return .none }
                state.isAutoBlending.toggle()

                if state.isAutoBlending {
                    let maxDuration = 0.7
                    let pauseDuration = 0.3
                    let currentBlend = state.blend

                    let initialTarget: Double
                    let initialDistance: Double

                    if currentBlend < 0.5 {
                        initialTarget = 1.0
                        initialDistance = 1.0 - currentBlend
                    } else {
                        initialTarget = 0.0
                        initialDistance = currentBlend
                    }

                    let initialDuration = maxDuration * initialDistance

                    return .run { send in
                        // First, animate to the initial target
                        await send(.setBlend(initialTarget), animation: .linear(duration: initialDuration))
                        try await Task.sleep(for: .seconds(initialDuration + pauseDuration))

                        var currentTarget = initialTarget

                        // Now, loop forever, alternating
                        while true {
                            currentTarget = currentTarget == 1.0 ? 0.0 : 1.0
                            await send(.setBlend(currentTarget), animation: .linear(duration: maxDuration))
                            try await Task.sleep(for: .seconds(maxDuration + pauseDuration))
                        }
                    }
                    .cancellable(id: CancellableID.autoBlend)
                } else {
                    return .cancel(id: CancellableID.autoBlend)
                }
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
