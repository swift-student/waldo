import SwiftUI

/// NSViewRepresentable that provides comprehensive gesture support for zoom and pan operations.
/// Handles trackpad scroll, magnification gestures, pan gestures, and double-click reset.
struct GestureOverlayView: NSViewRepresentable {
    @Bindable var zoomPanState: ZoomPanState

    func makeNSView(context: Context) -> ScrollHandlingView {
        let view = ScrollHandlingView()
        view.coordinator = context.coordinator
        
        // Pan gesture for drag panning
        let panGesture = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))

        // Magnification gesture for zoom
        let magnificationGesture = NSMagnificationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMagnification(_:)))
        
        // Double-click gesture for reset
        let doubleClickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        
        // Set the coordinator as delegate for gesture recognizers
        panGesture.delegate = context.coordinator
        magnificationGesture.delegate = context.coordinator
        doubleClickGesture.delegate = context.coordinator

        view.addGestureRecognizer(panGesture)
        view.addGestureRecognizer(magnificationGesture)
        view.addGestureRecognizer(doubleClickGesture)
        
        return view
    }
    
    /// Custom NSView that handles scroll wheel events for trackpad panning
    class ScrollHandlingView: NSView {
        var coordinator: Coordinator?

        override func scrollWheel(with event: NSEvent) {
            coordinator?.handleScrollWheel(event)
        }
    }

    func updateNSView(_ nsView: ScrollHandlingView, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// Coordinator that handles all gesture recognition and delegates to ZoomPanState
    class Coordinator: NSObject, NSGestureRecognizerDelegate {
        var parent: GestureOverlayView

        init(_ parent: GestureOverlayView) {
            self.parent = parent
        }
        
        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)

            switch gesture.state {
            case .changed:
                // Only allow panning when zoomed in
                if parent.zoomPanState.scale > 1.0 {
                    // Flip the y-axis to match SwiftUI coordinate system
                    parent.zoomPanState.updateOffset(gestureTranslation: CGSize(width: translation.x, height: -translation.y))
                }
            case .ended, .cancelled:
                if parent.zoomPanState.scale > 1.0 {
                    parent.zoomPanState.finalizeOffset()
                }
                gesture.setTranslation(.zero, in: gesture.view)
            case .failed:
                gesture.setTranslation(.zero, in: gesture.view)
            default:
                break
            }
        }
        
        @objc func handleMagnification(_ gesture: NSMagnificationGestureRecognizer) {

            switch gesture.state {
            case .changed:
                parent.zoomPanState.updateScale(gestureScale: 1.0 + gesture.magnification)
            case .ended, .cancelled:
                parent.zoomPanState.finalizeScale()
                gesture.magnification = 0
            case .failed:
                gesture.magnification = 0
            default:
                break
            }
        }
        
        @objc func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
            withAnimation(.easeInOut(duration: 0.3)) {
                parent.zoomPanState.reset()
            }
        }
        
        func handleScrollWheel(_ event: NSEvent) {

            // Only handle scroll when zoomed in
            guard parent.zoomPanState.scale > 1.0 else { 
                return
            }
            
            let currentOffset = parent.zoomPanState.offset
            let newOffset = CGSize(
                width: currentOffset.width + event.scrollingDeltaX,
                height: currentOffset.height + event.scrollingDeltaY
            )
            
            parent.zoomPanState.offset = newOffset
            parent.zoomPanState.constrainValues()
            
            // Only finalize when the scroll gesture ends
            if event.phase == .ended || event.momentumPhase == .ended {
                parent.zoomPanState.finalizeOffset()
            }
        }
    }
}