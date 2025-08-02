import Clocks
import ComposableArchitecture
@testable import Diffi
import Foundation
@testable import Git
import Testing

@Suite("DiffFeature Tests")
struct DiffFeatureTests {
    let repoFolder = URL(fileURLWithPath: "/test/repo")
    let testFiles = [PickableFile(path: "test.swift", status: .modified)]
    let testError = GitError.testError
    let clock = TestClock()

    @Test @MainActor
    func startDiffPolling() async {
        let store = TestStore(
            initialState: DiffFeature.State(repoFolder: repoFolder)
        ) {
            DiffFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.gitService.performDiff = { _ in .success(testFiles) }
        }

        await store.send(.startDiffPolling) {
            $0.isDiffPolling = true
            $0.failureCount = 0
            $0.currentFailureResponse = nil
            $0.currentError = nil
        }

        await store.receive(.diffResult(.success(testFiles)))

        for _ in 0 ..< 10 {
            await clock.advance(by: .seconds(DiffFeature.pollingInterval))
            await store.receive(.scheduledDiffAttempt)
            await store.receive(.diffResult(.success(testFiles)))
        }

        // Stop polling
        await store.send(.stopDiffPolling) {
            $0.isDiffPolling = false
            $0.failureCount = 0
            $0.currentFailureResponse = nil
            $0.currentError = nil
        }
    }

    @Test @MainActor
    func startDiffPollingWithoutRepo() async {
        let store = TestStore(
            initialState: DiffFeature.State()
        ) {
            DiffFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.gitService.performDiff = { _ in .success(testFiles) }
        }

        await store.send(.startDiffPolling)
    }

    @Test @MainActor
    func stopDiffPolling_AfterFailure() async {
        let store = TestStore(
            initialState: DiffFeature.State(
                repoFolder: repoFolder,
                isDiffPolling: true,
                failureCount: 2,
                currentFailureResponse: .wait(5),
                currentError: testError
            )
        ) {
            DiffFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.stopDiffPolling) {
            $0.isDiffPolling = false
            $0.failureCount = 0
            $0.currentFailureResponse = nil
            $0.currentError = nil
        }
    }

    @Test @MainActor
    func successfulDiffResult_AfterFailure() async {
        let store = TestStore(
            initialState: DiffFeature.State(
                repoFolder: repoFolder,
                isDiffPolling: true,
                failureCount: 3,
                currentFailureResponse: .showErrorToast(andWait: 10),
                currentError: testError
            )
        ) {
            DiffFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.gitService.performDiff = { _ in .success(testFiles) }
        }

        await store.send(.diffResult(.success(testFiles))) {
            $0.failureCount = 0
            $0.currentFailureResponse = nil
            $0.currentError = nil
        }

        await clock.advance(by: .seconds(DiffFeature.pollingInterval))
        await store.receive(.scheduledDiffAttempt)
        await store.receive(.diffResult(.success(testFiles)))

        await store.send(.stopDiffPolling) {
            $0.isDiffPolling = false
            $0.failureCount = 0
            $0.currentFailureResponse = nil
            $0.currentError = nil
        }
    }

    @Test @MainActor
    func failureBackoffProgression() async {
        let store = TestStore(
            initialState: DiffFeature.State(repoFolder: repoFolder, isDiffPolling: true)
        ) {
            DiffFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.gitService.performDiff = { _ in .failure(testError) }
        }

        await store.send(.scheduledDiffAttempt)

        for failure in DiffFeature.FailureResponse.defaultBackoffStrategy.indices {
            await store.receive(.diffResult(.failure(testError))) {
                $0.failureCount = failure + 1
                $0.currentFailureResponse = DiffFeature.FailureResponse.defaultBackoffStrategy[failure]
                $0.currentError = testError
            }
            await clock.advance(by: .seconds(DiffFeature.FailureResponse.defaultBackoffStrategy[failure].delay))
            await store.receive(.scheduledDiffAttempt)
        }

        await store.receive(.diffResult(.failure(testError))) {
            $0.failureCount = DiffFeature.FailureResponse.defaultBackoffStrategy.count + 1
            $0.currentFailureResponse = DiffFeature.FailureResponse.defaultBackoffStrategy.last
            $0.currentError = testError
        }

        await store.send(.stopDiffPolling) {
            $0.isDiffPolling = false
            $0.failureCount = 0
            $0.currentFailureResponse = nil
            $0.currentError = nil
        }
    }

    @Test @MainActor
    func scheduledDiffAttempt_WithoutActivePolling() async {
        let store = TestStore(
            initialState: DiffFeature.State(
                repoFolder: repoFolder,
                isDiffPolling: false
            )
        ) {
            DiffFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.gitService.performDiff = { _ in .success([]) }
        }

        await store.send(.scheduledDiffAttempt)
    }

    @Test @MainActor
    func scheduledDiffAttempt_WithoutRepo() async {
        let store = TestStore(
            initialState: DiffFeature.State(isDiffPolling: true)
        ) {
            DiffFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.gitService.performDiff = { _ in .success([]) }
        }

        await store.send(.scheduledDiffAttempt)
    }
}

private extension GitError {
    static let testError = GitError.failedToOpenRepo(Clibgit2Error(code: .notFound))
}
