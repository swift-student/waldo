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

    /// Size of the image in its natural dimensions
    var imageSize: CGSize = .zero

    /// Size of the container/viewport
    var containerSize: CGSize = .zero

    /// Minimum allowed zoom level (normal size)
    private let minScale: CGFloat = 1.0

    /// Maximum allowed zoom level
    private let maxScale: CGFloat = 5.0

    private var imageAspect: CGFloat {
        imageSize.width / imageSize.height
    }

    private var containerAspect: CGFloat {
        containerSize.width / containerSize.height
    }

    private var fittedSize: CGSize {
        let fittedWidth: CGFloat
        let fittedHeight: CGFloat

        if imageAspect > containerAspect {
            // Image is wider - fits to container width
            fittedWidth = containerSize.width
            fittedHeight = containerSize.width / imageAspect
        } else {
            // Image is taller - fits to container height
            fittedHeight = containerSize.height
            fittedWidth = containerSize.height * imageAspect
        }

        return CGSize(width: fittedWidth, height: fittedHeight)
    }

    /// The frame size that expands proportionally with zoom to give more space for scaling
    var expandedFrameSize: CGSize {
        let expandedWidth = min(fittedSize.width * scale, containerSize.width)
        let expandedHeight = min(fittedSize.height * scale, containerSize.height)

        return CGSize(width: expandedWidth, height: expandedHeight)
    }

    /// Resets zoom and pan to default state.
    /// Called when user double-clicks or when programmatically resetting view.
    func reset() {
        scale = minScale
        offset = .zero
    }

    private func setOffset(_ offset: CGSize) {
        let scaledWidth = fittedSize.width * scale
        let scaledHeight = fittedSize.height * scale

        // Calculate maximum pan distance to keep image filling the container
        // The scaled image content should not go beyond the container edges
        let maxOffsetX = max(0, (scaledWidth - containerSize.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - containerSize.height) / 2)

        let clampedOffset = CGSize(
            width: min(max(-maxOffsetX, offset.width), maxOffsetX),
            height: min(max(-maxOffsetY, offset.height), maxOffsetY)
        )

        _offset = clampedOffset
    }
}
