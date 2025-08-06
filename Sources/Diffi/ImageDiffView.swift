import ComposableArchitecture
import Foundation
import Git
import SwiftUI

struct ImageDiffView: View {
    @Bindable var store: StoreOf<ImageDiffFeature>

    var body: some View {
        HStack(spacing: 20) {
            VStack {
                Text(previousVersionTitle)
                    .font(.headline)

                previousVersionContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                Text(currentVersionTitle)
                    .font(.headline)

                currentVersionContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .alert(
            "Error",
            isPresented: .constant(store.error != nil),
            actions: {
                Button("OK") {
                    store.send(.clearError)
                }
            },
            message: {
                if let error = store.error {
                    Text(error.debugDescription)
                }
            }
        )
        .onAppear {
            store.send(.onAppear)
        }
    }

    private var previousVersionTitle: String {
        switch store.selectedFile?.status {
        case .added:
            return "New File"
        default:
            return "Before (HEAD)"
        }
    }

    private var currentVersionTitle: String {
        switch store.selectedFile?.status {
        case .added:
            return "Current (New)"
        default:
            return "After (Working)"
        }
    }

    @ViewBuilder
    private var previousVersionContent: some View {
        if store.selectedFile?.status == .added {
            VStack {
                Image(systemName: "plus.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                Text("This is a new file")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let data = store.previousVersionData,
                  let nsImage = NSImage(data: data)
        {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if store.isLoading {
            ProgressView("Loading previous version...")
        } else {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                Text("Could not load previous version")
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var currentVersionContent: some View {
        if let data = store.currentVersionData,
           let nsImage = NSImage(data: data)
        {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if store.isLoading {
            ProgressView("Loading current version...")
        } else {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                Text("Could not load current version")
                    .foregroundColor(.secondary)
            }
        }
    }
}

