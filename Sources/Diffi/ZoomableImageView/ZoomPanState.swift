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
    var scale: CGFloat {
        get { _scale }
        set {
            _scale = min(maxScale, max(minScale, newValue))
            setOffset(_offset) // Adjust offset to stay within bounds after scaling
        }
    }

    var _scale: CGFloat = 1.0

    var offset: CGSize {
        get { _offset }
        set {
            setOffset(newValue)
        }
    }

    /// Current pan offset from the center position
    var _offset: CGSize = .zero

    /// Minimum allowed zoom level (normal size)
    private let minScale: CGFloat = 1.0

    /// Maximum allowed zoom level
    private let maxScale: CGFloat = 5.0

    /// Resets zoom and pan to default state.
    /// Called when user double-clicks or when programmatically resetting view.
    func reset() {
        scale = minScale
        offset = .zero
    }

    private func setOffset(_ offset: CGSize) {
        // TODO: This doesn't allow the user to pan to the edges of the image
        // How would we calculate the maximum offset based on the image size?
        let maxOffset: CGFloat = 200 * (scale - 1)
        _offset = CGSize(
            width: min(max(-maxOffset, offset.width), maxOffset),
            height: min(max(-maxOffset, offset.height), maxOffset)
        )
    }
}
