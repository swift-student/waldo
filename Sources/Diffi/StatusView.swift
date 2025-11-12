import ComposableArchitecture
import SwiftUI
import Git

// TODO: Fix this up or replace it, this is just a spike to see how well this would work.
struct StatusView: View {
    let status: Git.Diff.Status?
    let previousState: ImageLoadState?
    let currentState: ImageLoadState?
    let viewMode: ImageDiffViewMode
    let blend: Double
    let onBlendChanged: (Double) -> Void

    var body: some View {
        if viewMode == .onionSkin {
            onionSkinStatus
        } else {
            sideBySideStatus
        }
    }

    private var sideBySideStatus: some View {
        HStack {
            switch status {
            case .added, .untracked:
                HStack {
                    VStack {
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(Color.green)
                                .font(.system(size: 8))

                            Text("Created")

                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .hidden()
                        }
                        .font(.headline)
                        if let size = currentState?.size {
                            sizeLabel(size: size)
                        }
                    }
                }
            case .deleted:
                HStack {
                    VStack {
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(Color.red)
                                .font(.system(size: 8))

                            Text("Deleted")

                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .hidden()
                        }
                        .font(.headline)
                        if let size = previousState?.size {
                            sizeLabel(size: size)
                        }
                    }
                }
            default:
                VStack(alignment: .trailing) {
                    Text("Before")
                        .font(.headline)
                    if let size = previousState?.size {
                        sizeLabel(size: size)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading) {
                    Text("After")
                        .font(.headline)
                    if let size = currentState?.size {
                        sizeLabel(size: size)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var onionSkinStatus: some View {
        if case .loaded = previousState, case .loaded = currentState {
            HStack {
                VStack(alignment: .trailing) {
                    Text("Before")
                        .font(.system(size: 12, weight: .semibold))
                    if let size = previousState?.size {
                        sizeLabel(size: size)
                            .foregroundColor(.secondary)
                    }
                }

                Slider(value: Binding(get: { blend }, set: onBlendChanged), in: 0.0 ... 1.0)
                    .frame(minWidth: 200)
                    .padding(.horizontal)

                VStack(alignment: .leading) {
                    Text("After")
                        .font(.system(size: 12, weight: .semibold))
                    if let size = currentState?.size {
                        sizeLabel(size: size)
                    }
                }
            }
        } else {
            sideBySideStatus
        }
    }

    func sizeLabel(size: CGSize) -> some View {
        Text("W: \(Int(size.width))px H: \(Int(size.height))px")
            .font(.caption)
    }
}

extension ImageLoadState {
    var size: CGSize? {
        switch self {
        case .loaded(let loadedImage):
            return loadedImage.size
        default:
            return nil
        }
    }
}
