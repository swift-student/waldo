import ComposableArchitecture
import SwiftUI

struct FolderPicker: View {
    @Bindable var store: StoreOf<FolderPickerFeature>
    
    var body: some View {
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
                store.send(.failurePickingFolder(FolderPickerFeature.PickerError(error)))
            }
        }
    }
}