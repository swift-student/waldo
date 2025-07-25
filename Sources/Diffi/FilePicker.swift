import ComposableArchitecture
import Git
import SwiftUI

struct FilePicker: View {
    @Bindable var store: StoreOf<FilePickerFeature>

    var body: some View {
        List(store.files, id: \.self, selection: $store.selectedFile.sending(\.userSelectedFile)) { file in
            Text(file.path)
        }
        .navigationTitle("Files")
        .onKeyPress(.init("k")) { 
            store.send(.navigateUp)
            return .handled 
        }
        .onKeyPress(.init("j")) { 
            store.send(.navigateDown)
            return .handled 
        }
    }
}
