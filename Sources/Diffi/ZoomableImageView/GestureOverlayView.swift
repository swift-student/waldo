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
        private var isZoomingToCursor: Bool = false

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
            guard let view = gesture.view else { return }

            switch gesture.state {
            case .began:
                initialScale = parent.zoomPanState.scale
                initialOffset = parent.zoomPanState.offset

                // Decide on the zoom mode at the start of the gesture and lock it in.
                let locationInView = gesture.location(in: view)
                let location = CGPoint(x: locationInView.x, y: view.bounds.height - locationInView.y)
                let state = parent.zoomPanState
                let containerCenter = CGPoint(x: state.containerSize.width / 2, y: state.containerSize.height / 2)
                let imageRect = CGRect(
                    x: containerCenter.x - state.scaledSize.width / 2 + state.offset.width,
                    y: containerCenter.y - state.scaledSize.height / 2 + state.offset.height,
                    width: state.scaledSize.width,
                    height: state.scaledSize.height
                )
                isZoomingToCursor = imageRect.contains(location)

            case .changed:
                let unclampedRatio = 1.0 + gesture.magnification
                let unclampedTargetScale = initialScale * unclampedRatio

                parent.zoomPanState.scale = unclampedTargetScale
                let clampedScale = parent.zoomPanState.scale

                guard isZoomingToCursor else { break }

                let ratio = clampedScale / initialScale
                let locationInView = gesture.location(in: view)
                let location = CGPoint(x: locationInView.x, y: view.bounds.height - locationInView.y)
                let containerCenter = CGPoint(x: parent.zoomPanState.containerSize.width / 2, y: parent.zoomPanState.containerSize.height / 2)

                let targetOffsetX = (location.x - containerCenter.x) * (1 - ratio) + initialOffset.width * ratio
                let targetOffsetY = (location.y - containerCenter.y) * (1 - ratio) + initialOffset.height * ratio
                parent.zoomPanState.offset = CGSize(width: targetOffsetX, height: targetOffsetY)

            case .ended:
                // If the gesture ends at the minimum scale, animate back to center.
                if parent.zoomPanState.scale == 1.0 {
                    withAnimation(.easeOut(duration: 0.3)) {
                        parent.zoomPanState.offset = .zero
                    }
                }

            case .cancelled, .failed:
                parent.zoomPanState.scale = initialScale
                parent.zoomPanState.offset = initialOffset

            default:
                break
            }
        }

        @objc
        fileprivate func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
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
