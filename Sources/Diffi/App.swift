import SwiftUI
import ComposableArchitecture

@main
struct DiffiApp: App {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }
    
    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
        .windowResizability(.contentMinSize)
    }
}