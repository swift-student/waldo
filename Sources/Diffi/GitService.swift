import ComposableArchitecture
import Foundation
import Git

struct GitService {
    var performDiff: (URL) -> Result<[PickableFile], GitError>
    var showFile: (URL, String, String) -> Result<Data, GitError>
}

extension GitService: DependencyKey {
    static var liveValue: Self {
        return Self(
            performDiff: { repoFolder in
                do throws(GitError) {
                    let repo = try Git.Repo(url: repoFolder)
                    let diffChanges = try repo.diffNameStatusWorkingTree()
                    print("Diff changes count: \(diffChanges.count)")
                    
                    let untrackedChanges = try repo.getUntrackedFiles()
                    print("Untracked changes count: \(untrackedChanges.count)")
                    
                    let allChanges = diffChanges + untrackedChanges
                    print("Total changes count: \(allChanges.count)")
                    
                    let pickableFiles = allChanges.map { PickableFile(from: $0) }
                    return .success(pickableFiles)
                } catch {
                    print("GitService error: \(error)")
                    return .failure(error)
                }
            },
            showFile: { repoFolder, revspec, filePath in
                do throws(GitError) {
                    let repo = try Git.Repo(url: repoFolder)
                    let data = try repo.show(revspec: revspec, filePath: filePath)
                    return .success(data)
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
