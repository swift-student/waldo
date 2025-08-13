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
        case let .loaded(loadedImage):
            ZoomableImageView(image: loadedImage.image, imageSize: loadedImage.size, zoomPanState: zoomPanState)
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
            switch store.viewMode {
            case .sideBySide:
                sideBySideContent
            case .onionSkin:
                onionSkinContent
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("View Mode", selection: Binding(
                    get: { store.viewMode },
                    set: { store.send(.setViewMode($0)) }
                )) {
                    Image(systemName: "rectangle.split.2x1")
                        .tag(ImageDiffViewMode.sideBySide)
                    Image(systemName: "circle.lefthalf.filled")
                        .tag(ImageDiffViewMode.onionSkin)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    @ViewBuilder
    private var sideBySideContent: some View {
        HStack(spacing: 20) {
            if store.previousVersionState != nil {
                ImageVersionView(
                    title: previousVersionTitle,
                    state: store.previousVersionState,
                    zoomPanState: zoomPanState
                )
            }

            ImageVersionView(
                title: currentVersionTitle,
                state: store.currentVersionState,
                zoomPanState: zoomPanState
            )
        }
    }

    @ViewBuilder
    private var onionSkinContent: some View {
        OnionSkinImageView(
            previousVersionState: store.previousVersionState,
            currentVersionState: store.currentVersionState,
            opacityBlend: store.opacityBlend,
            previousVersionTitle: previousVersionTitle,
            currentVersionTitle: currentVersionTitle,
            zoomPanState: zoomPanState,
            onOpacityChanged: { blend in
                store.send(.setOpacityBlend(blend))
            }
        )
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
