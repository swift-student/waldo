import Foundation
import Git

public struct PickableFile: Hashable, Equatable, Identifiable {
    public let id: String
    public let path: String
    public let status: Git.Diff.Status

    public init(path: String, status: Git.Diff.Status) {
        self.path = path
        self.status = status
        id = path
    }

    public init(from fileChange: Git.Diff.FileChange) {
        path = fileChange.path
        status = fileChange.status
        id = fileChange.id
    }
}

extension PickableFile {
    var isImageFile: Bool {
        guard let url = URL(string: path) else {
            return false
        }

        // TODO: Are all of these image files compatible with the image diffing?
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "webp", "ico", "svg"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
}
