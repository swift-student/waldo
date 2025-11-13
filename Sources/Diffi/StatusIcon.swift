import Git
import SwiftUI

struct StatusIcon: View {

    private let status: Git.Diff.Status

    init(_ status: Git.Diff.Status) {
        self.status = status
    }

    var body: some View {
        if let (image, color) = statusInfo {
            image.foregroundStyle(color)
        }
    }

    private var statusInfo: (Image, Color)? {
        switch status {
        case .added, .untracked:
            (Image(systemName: "plus.square.fill"), .green)
        case .deleted:
            (Image(systemName: "minus.square.fill"), .red)
        case .modified:
            (Image(systemName: "m.square.fill"), .yellow)
        default:
            nil
        }
    }
    
}
