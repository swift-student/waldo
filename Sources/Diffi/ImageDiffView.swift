import ComposableArchitecture
import Foundation
import Git
import SwiftUI

struct ImageVersionView: View {
    let title: String
    let state: ImageLoadState?
    @Bindable var zoomPanState: ZoomPanState

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView("Loading...")
        case let .loaded(image):
            ZoomableImageView(image: image, zoomPanState: zoomPanState)
        case let .error(error):
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))

                Text("Could not load image")
                    .foregroundColor(.secondary)
                Text(error.debugDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .none:
            EmptyView()
        }
    }
}

struct ImageDiffView: View {
    @Bindable var store: StoreOf<ImageDiffFeature>
    @State private var zoomPanState = ZoomPanState()

    var body: some View {
        Group {
            if store.previousVersionState != nil {
                HStack(spacing: 20) {
                    ImageVersionView(
                        title: previousVersionTitle,
                        state: store.previousVersionState,
                        zoomPanState: zoomPanState
                    )

                    ImageVersionView(
                        title: currentVersionTitle,
                        state: store.currentVersionState,
                        zoomPanState: zoomPanState
                    )
                }
            } else {
                ImageVersionView(
                    title: currentVersionTitle,
                    state: store.currentVersionState,
                    zoomPanState: zoomPanState
                )
            }
        }
        .padding()
        .onAppear {
            store.send(.onAppear)
        }
    }

    private var previousVersionTitle: String {
        switch store.selectedFile?.status {
        case .added, .untracked:
            return "New File"
        default:
            return "Before (HEAD)"
        }
    }

    private var currentVersionTitle: String {
        switch store.selectedFile?.status {
        case .added, .untracked:
            return "Current (New)"
        default:
            return "After (Working)"
        }
    }
}
