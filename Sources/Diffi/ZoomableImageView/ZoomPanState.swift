import SwiftUI

/// Manages zoom and pan state for image viewing with gesture support.
/// 
/// This class uses a "base + delta" pattern for gesture handling, where:
/// - Base values represent the committed state when no gesture is active
/// - Current values represent the live state during gesture interaction
/// - Gestures accumulate changes on top of base values to avoid drift
@Observable
class ZoomPanState {
    /// Current zoom scale factor (1.0 = normal size, 5.0 = maximum zoom)
    var scale: CGFloat = 1.0
    
    /// Current pan offset from the center position
    var offset: CGSize = .zero

    /// Base scale value when gesture started - prevents accumulation drift
    private var baseScale: CGFloat = 1.0
    
    /// Base offset value when gesture started - prevents accumulation drift  
    private var baseOffset: CGSize = .zero

    /// Minimum allowed zoom level (normal size)
    let minScale: CGFloat = 1.0
    
    /// Maximum allowed zoom level
    let maxScale: CGFloat = 5.0

    /// Resets zoom and pan to default state.
    /// Called when user double-clicks or when programmatically resetting view.
    func reset() {
        scale = minScale
        offset = .zero
        baseScale = minScale
        baseOffset = .zero
    }

    /// Updates scale during magnification gesture.
    /// 
    /// - Parameter gestureScale: Cumulative scale from gesture (1.0 = no change)
    func updateScale(gestureScale: CGFloat) {
        scale = baseScale * gestureScale
        constrainValues()
    }

    /// Commits the current scale as the new base value.
    /// Called when magnification gesture ends.
    func finalizeScale() {
        baseScale = scale
    }

    /// Updates offset during pan or scroll gesture.
    /// 
    /// - Parameter gestureTranslation: Cumulative translation from gesture
    func updateOffset(gestureTranslation: CGSize) {
        offset = CGSize(
            width: baseOffset.width + gestureTranslation.width,
            height: baseOffset.height + gestureTranslation.height
        )
        constrainValues()
    }

    /// Commits the current offset as the new base value.
    /// Called when pan or scroll gesture ends.
    func finalizeOffset() {
        baseOffset = offset
    }

    /// Enforces bounds on scale and offset values.
    /// 
    /// - Scale is clamped between minScale and maxScale
    /// - Offset is constrained based on current scale to prevent excessive panning
    /// - Higher zoom levels allow more panning range
    func constrainValues() {
        scale = max(minScale, min(maxScale, scale))

        // Scale-based offset constraint: more zoom = more allowed panning
        let maxOffset: CGFloat = 200 * (scale - 1)
        offset.width = max(-maxOffset, min(maxOffset, offset.width))
        offset.height = max(-maxOffset, min(maxOffset, offset.height))
    }
}