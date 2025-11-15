import ComposableArchitecture
import Foundation
import Git
import SwiftUI

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
        .onChange(of: store.selectedFile) {
            zoomPanState.reset()
        }
        .toolbar {
            toolbarContent
        }
        .secondaryToolbar {
            StatusView(
                status: store.selectedFile?.status,
                previousState: store.previousVersionState,
                currentState: store.currentVersionState,
                viewMode: store.viewMode,
                isAutoBlending: store.isAutoBlending,
                blend: store.blend,
                onBlendChanged: { store.send(.setBlend($0)) }
            )
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                store.send(.toggleAutoBlend)
            } label: {
                Image(systemName: store.isAutoBlending ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .padding()
            }
            .disabled(!store.viewMode.blendable)
        }

        ToolbarItem(placement: .principal) {
            if let path = store.selectedFile?.path {
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(.headline)
                    .frame(alignment: .center)
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Spacer()
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
}
