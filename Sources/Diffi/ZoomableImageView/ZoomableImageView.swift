import SwiftUI

/// A SwiftUI view that displays an image with zoom and pan capabilities.
/// Combines SwiftUI's transform modifiers with an NSView overlay for comprehensive gesture support.
struct ZoomableImageView: View {
    let image: Image
    let imageSize: CGSize
    @Bindable var zoomPanState: ZoomPanState

    var body: some View {
        GeometryReader { geometry in
            let containerCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: zoomPanState.scaledSize.width,
                        height: zoomPanState.scaledSize.height
                    )
                    .position(containerCenter)
                    .offset(zoomPanState.offset)
                    .clipped()
                    .allowsHitTesting(false)
                    .onAppear {
                        updateDimensions(containerSize: geometry.size)
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        updateDimensions(containerSize: newSize)
                    }

                GestureOverlayView(zoomPanState: zoomPanState)
            }
        }
    }
    
    private func updateDimensions(containerSize: CGSize) {
        zoomPanState.containerSize = containerSize
        zoomPanState.imageSize = imageSize
    }
}

