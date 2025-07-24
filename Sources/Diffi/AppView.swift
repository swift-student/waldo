import ComposableArchitecture
import SwiftUI

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        if let folder = store.repoFolder {
            NavigationSplitView {
                List {
                    if let fileChanges = store.fileChanges {
                        ForEach(fileChanges, id: \.path) { fileChange in
                            Text(fileChange.path)
                        }
                    } else {
                        Text("No changes")
                    }
                }
                .navigationTitle("Files")
            } detail: {
                Text("Select a file to view details")
            }
        } else {
            VStack {
                Text("Select a Git Repository")
                Button("Choose Folder") {
                    store.send(.showingFolderPickerChanged(true))
                }
            }
            // TODO: Instrument this and see why it takes so long to show this
            .fileImporter(
                isPresented: $store.showingFolderPicker.sending(\.showingFolderPickerChanged),
                allowedContentTypes: [.folder]
            ) { result in
                switch result {
                case let .success(folder):
                    store.send(.userPickedFolder(folder))
                case let .failure(error):
                    store.send(.failurePickingFolder(error))
                }
            }
        }
    }
}
