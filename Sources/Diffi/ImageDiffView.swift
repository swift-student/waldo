import ComposableArchitecture
import Foundation
import Git
import SwiftUI



struct ImageVersionView: View {
    let state: ImageLoadState?
    @Bindable var zoomPanState: ZoomPanState
    var isDeleted: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(isDeleted ? 0.3 : 1.0)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView("Loading...")
        case let .loaded(loadedImage):
            ZoomableImageView(image: loadedImage.image, imageSize: loadedImage.size, zoomPanState: zoomPanState)
        case .error(let error):
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))

                Text("Could not load image")
                    .foregroundColor(.secondary)
                Text(error.debugDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .deleted, .none:
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
        .onChange(of: store.selectedFile) {
            zoomPanState.reset()
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .principal) {
                StatusView(
                    status: store.selectedFile?.status,
                    previousState: store.previousVersionState,
                    currentState: store.currentVersionState,
                    viewMode: store.viewMode,
                    blend: store.blend,
                    onBlendChanged: { store.send(.setBlend($0)) }
                )
            }

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
            if store.selectedFile?.status == .deleted {
                ImageVersionView(
                    state: store.previousVersionState,
                    zoomPanState: zoomPanState,
                    isDeleted: true
                )
            } else {
                if store.previousVersionState != nil {
                    ImageVersionView(
                        state: store.previousVersionState,
                        zoomPanState: zoomPanState
                    )
                }

                ImageVersionView(
                    state: store.currentVersionState,
                    zoomPanState: zoomPanState
                )
            }
        }
    }

    @ViewBuilder
    private var onionSkinContent: some View {
        OnionSkinImageView(
            previousVersionState: store.previousVersionState,
            currentVersionState: store.currentVersionState,
            blend: store.blend,
            zoomPanState: zoomPanState,
            onOpacityChanged: { blend in
                store.send(.setBlend(blend))
            }
        )
    }
}
