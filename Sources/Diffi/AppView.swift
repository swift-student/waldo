import ComposableArchitecture
import Git
import SwiftUI

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        if store.diffFeature.repoFolder != nil {
            NavigationSplitView {
                FilePicker(
                    store: store.scope(
                        state: \.filePickerFeature,
                        action: \.filePickerFeature
                    )
                )
            } detail: {
                if let selectedFile = store.filePickerFeature.selectedFile,
                   selectedFile.isImageFile {
                    ImageDiffView(
                        store: store.scope(
                            state: \.imageDiffFeature,
                            action: \.imageDiffFeature
                        )
                    )
                } else {
                    Text("Select a file to view details")
                }
            }
            .onKeyPress(.init("m")) {
                store.send(.imageDiffFeature(.selectNextViewMode))
                return .handled
            }
            .onKeyPress(.init("a")) {
                store.send(.imageDiffFeature(.toggleAutoBlend))
                return .handled
            }
        } else {
            FolderPicker(
                store: store.scope(
                    state: \.folderPickerFeature,
                    action: \.folderPickerFeature
                )
            )
        }
    }
}
