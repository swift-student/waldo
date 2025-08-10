import SwiftUI

/// A SwiftUI view that displays an image with zoom and pan capabilities.
/// Combines SwiftUI's transform modifiers with an NSView overlay for comprehensive gesture support.
struct ZoomableImageView: View {
    let image: Image
    @Bindable var zoomPanState: ZoomPanState

    var body: some View {
        ZStack {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(zoomPanState.scale)
                .offset(zoomPanState.offset)
                .clipped()
                .allowsHitTesting(false)

            // NSView overlay handles all gestures
            GestureOverlayView(zoomPanState: zoomPanState)
        }
    }
}

