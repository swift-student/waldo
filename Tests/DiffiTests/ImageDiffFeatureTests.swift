import Clocks
import ComposableArchitecture
@testable import Diffi
@testable import Git
import Testing
import SwiftUI

@Suite("ImageDiffFeature Tests")
struct ImageDiffFeatureTests {

    @Test @MainActor
    func defaultState() async {
        let store = TestStore(initialState: ImageDiffFeature.State(
            selectedFile: Shared(value: nil)
        )) {
            ImageDiffFeature()
        }

        #expect(store.state.viewMode == .sideBySide)
        #expect(store.state.blend == 0.5)
    }
    
    @Test @MainActor
    func setViewMode() async {
        let store = TestStore(initialState: ImageDiffFeature.State(
            selectedFile: Shared(value: nil)
        )) {
            ImageDiffFeature()
        }
        
        await store.send(.setViewMode(.onionSkin)) {
            $0.viewMode = .onionSkin
        }
        
        await store.send(.setViewMode(.sideBySide)) {
            $0.viewMode = .sideBySide
        }
    }
    
    @Test @MainActor
    func setBlend_WithinBounds() async {
        let store = TestStore(initialState: ImageDiffFeature.State(
            selectedFile: Shared(value: nil)
        )) {
            ImageDiffFeature()
        }
        
        await store.send(.setBlend(0.7)) {
            $0.blend = 0.7
        }
        
        await store.send(.setBlend(0.0)) {
            $0.blend = 0.0
        }
        
        await store.send(.setBlend(1.0)) {
            $0.blend = 1.0
        }
    }
    
    @Test @MainActor
    func setBlend_ClampsToBounds() async {
        let store = TestStore(initialState: ImageDiffFeature.State(
            selectedFile: Shared(value: nil)
        )) {
            ImageDiffFeature()
        }
        
        await store.send(.setBlend(-0.5)) {
            $0.blend = 0.0
        }
        
        await store.send(.setBlend(1.5)) {
            $0.blend = 1.0
        }
    }
    
}
