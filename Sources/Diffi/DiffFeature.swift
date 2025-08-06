import ComposableArchitecture
import Foundation
import Git
import PrintDebug
import SwiftUI

@Reducer
public struct DiffFeature {
    @ObservableState
    public struct State: Equatable {
        var repoFolder: URL?
        var isDiffPolling: Bool = false
        var failureCount: Int = 0
        var currentFailureResponse: FailureResponse?
        var currentError: GitError?
    }

    public enum Action: Equatable {
        case startDiffPolling
        case stopDiffPolling
        case diffResult(Result<[PickableFile], GitError>)
        case scheduledDiffAttempt
    }

    private enum CancellableID {
        case diffPolling
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.gitService) var gitService

    init() {
        // TODO: Where should this go and what should we do if it doesn't initialize. Also need to shutdown.
        try? Git.initialize()
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startDiffPolling:
                guard let repoFolder = state.repoFolder else { return .none }

                state.isDiffPolling = true
                clearFailureState(&state)
                return performDiff(repoFolder: repoFolder)

            case .stopDiffPolling:
                state.isDiffPolling = false
                clearFailureState(&state)
                return .cancel(id: CancellableID.diffPolling)

            case .diffResult(.success):
                clearFailureState(&state)
                return .run { [clock] send in
                    try await clock.sleep(for: .seconds(Self.pollingInterval))
                    await send(.scheduledDiffAttempt)
                }
                .cancellable(id: CancellableID.diffPolling)

            case let .diffResult(.failure(error)):
                let backoffStrategy = FailureResponse.defaultBackoffStrategy
                let failureResponse = backoffStrategy[clamped: state.failureCount]

                state.failureCount += 1
                state.currentFailureResponse = failureResponse
                state.currentError = error

                return .run { [clock] send in
                    try await clock.sleep(for: .seconds(failureResponse.delay))
                    await send(.scheduledDiffAttempt)
                }
                .cancellable(id: CancellableID.diffPolling)

            case .scheduledDiffAttempt:
                guard let repoFolder = state.repoFolder, state.isDiffPolling else {
                    state.isDiffPolling = false
                    clearFailureState(&state)
                    return .none
                }
                return performDiff(repoFolder: repoFolder)
            }
        }
    }

    private func performDiff(repoFolder: URL) -> Effect<Action> {
        return Effect.run { send in
            await send(.diffResult(gitService.performDiff(repoFolder)))
        }
    }

    private func clearFailureState(_ state: inout State) {
        state.failureCount = 0
        state.currentFailureResponse = nil
        state.currentError = nil
    }
}

extension DiffFeature {
    static let pollingInterval: TimeInterval = 5

    enum FailureResponse: Equatable {
        case wait(TimeInterval)
        case showErrorToast(andWait: TimeInterval)

        var delay: TimeInterval {
            switch self {
            case let .wait(delay),
                 let .showErrorToast(delay):
                return delay
            }
        }

        static let defaultBackoffStrategy: [Self] = [
            .wait(DiffFeature.pollingInterval),
            .wait(DiffFeature.pollingInterval),
            .showErrorToast(andWait: DiffFeature.pollingInterval * 2),
            .showErrorToast(andWait: DiffFeature.pollingInterval * 4),
            .showErrorToast(andWait: DiffFeature.pollingInterval * 8),
        ]
    }
}
