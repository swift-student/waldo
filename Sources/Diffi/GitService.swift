import ComposableArchitecture
import Foundation
import Git

struct GitService {
    var performDiff: (URL) -> Result<[PickableFile], GitError>
}

extension GitService: DependencyKey {
    static var liveValue: Self {
        return Self(
            performDiff: { repoFolder in
                do throws(GitError) {
                    let repo = try Git.Repo(url: repoFolder)
                    let fileChanges = try repo.diffNameStatusWorkingTree()
                    let pickableFiles = fileChanges.map { PickableFile(from: $0) }
                    return .success(pickableFiles)
                } catch {
                    return .failure(error)
                }
            }
        )
    }
}

extension DependencyValues {
    var gitService: GitService {
        get { self[GitService.self] }
        set { self[GitService.self] = newValue }
    }
}
