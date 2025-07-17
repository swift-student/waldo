import SwiftUI
import ComposableArchitecture

struct AppView: View {
    let store: StoreOf<AppFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            HStack(spacing: 0) {
                if viewStore.repositoryPath == nil {
                    VStack {
                        Text("Select a Git Repository")
                            .font(.title2)
                        Button("Choose Folder") {
                            viewStore.send(.folderPickerButtonTapped)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack {
                        Text("Changed Images")
                            .font(.headline)
                            .padding()
                        
                        List(viewStore.changedImageFiles, id: \.self, selection: viewStore.binding(
                            get: \.selectedFile,
                            send: AppFeature.Action.fileSelected
                        )) { file in
                            Text(file)
                        }
                    }
                    .frame(width: 300)
                    
                    Divider()
                    
                    if let selectedFile = viewStore.selectedFile,
                       let repoPath = viewStore.repositoryPath {
                        ImageDiffView(
                            repositoryPath: repoPath,
                            filePath: selectedFile
                        )
                    } else {
                        VStack {
                            Text("Select an image file to view diff")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .fileImporter(
                isPresented: viewStore.binding(
                    get: \.showingFolderPicker,
                    send: { _ in AppFeature.Action.folderPickerDismissed }
                ),
                allowedContentTypes: [.folder]
            ) { result in
                switch result {
                case .success(let url):
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    let gitPath = url.appendingPathComponent(".git")
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: gitPath.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                        viewStore.send(.folderSelected(url))
                    }
                case .failure:
                    break
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}