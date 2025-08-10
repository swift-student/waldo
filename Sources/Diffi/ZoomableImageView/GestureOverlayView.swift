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

    func updateNSView(_: ScrollHandlingView, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// Coordinator that handles all gesture recognition and delegates to ZoomPanState
    class Coordinator: NSObject {
        private var parent: GestureOverlayView

        init(_ parent: GestureOverlayView) {
            self.parent = parent
        }

        private var initialOffset: CGSize = .zero
        private var initialScale: CGFloat = 1.0

        @objc
        fileprivate func handlePan(_ gesture: NSPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)

            switch gesture.state {
            case .began:
                initialOffset = parent.zoomPanState.offset
            case .changed:
                // Only allow panning when zoomed in
                guard parent.zoomPanState.scale > 1.0 else { break }
                // Flip the y-axis to match SwiftUI coordinate system
                let newOffset = CGSize(
                    width: initialOffset.width + translation.x,
                    height: initialOffset.height - translation.y
                )
                parent.zoomPanState.offset = newOffset
            case .cancelled, .failed:
                parent.zoomPanState.offset = initialOffset
            default:
                break
            }
        }

        @objc
        fileprivate func handleMagnification(_ gesture: NSMagnificationGestureRecognizer) {
            switch gesture.state {
            case .began:
                initialScale = parent.zoomPanState.scale
            case .changed:
                parent.zoomPanState.scale = initialScale * (1.0 + gesture.magnification)
            case .cancelled, .failed:
                parent.zoomPanState.scale = initialScale
            default:
                break
            }
        }

        @objc
        fileprivate func handleDoubleClick(_: NSClickGestureRecognizer) {
            withAnimation(.easeInOut(duration: 0.3)) {
                parent.zoomPanState.reset()
            }
        }

        fileprivate func handleScrollWheel(_ event: NSEvent) {
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
        }
    }
}
