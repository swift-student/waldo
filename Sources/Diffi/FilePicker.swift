import ComposableArchitecture
import Git
import SwiftUI

struct FilePicker: View {
    @Bindable var store: StoreOf<FilePickerFeature>

    var body: some View {
        ScrollViewReader { proxy in
            List(store.files, id: \.self, selection: $store.selectedFile.sending(\.userSelectedFile)) { file in
                HStack {
                    StatusIcon(file.status)
                    Text(file.path)
                        .truncationMode(.middle)
                }
                .id(file.path)
                .contextMenu {
                    Button("Show in Finder") {
                        store.send(.showInFinder(file))
                    }
                }
            }
            .navigationTitle("Files")
            // TODO: Make keys configurable
            .onKeyPress(.init("k")) {
                store.send(.navigateUp)
                return .handled
            }
            .onKeyPress(.init("j")) {
                store.send(.navigateDown)
                return .handled
            }
            .onChange(of: store.selectedFile) { _, selectedFile in
                guard let selectedFile else { return }
                proxy.scrollTo(selectedFile.path)
            }
        }
    }
}

