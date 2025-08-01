import SwiftUI
import ComposableArchitecture
import Diffi

@main
struct DiffiAppMain: App {
    let store = Store(initialState: AppFeature.State.make()) {
        AppFeature()
    }
    
    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
        .windowResizability(.contentMinSize)
    }
}
