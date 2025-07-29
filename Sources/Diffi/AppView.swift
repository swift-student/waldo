import ComposableArchitecture
import Git
import SwiftUI

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        if store.repoFolder != nil {
            NavigationSplitView {
                FilePicker(
                    store: store.scope(
                        state: \.filePickerFeature,
                        action: \.filePickerFeature
                    )
                )
            } detail: {
                Text("Select a file to view details")
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
