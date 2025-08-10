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

    /// Resets zoom and pan to default state.
    /// Called when user double-clicks or when programmatically resetting view.
    func reset() {
        scale = minScale
        offset = .zero
    }

    private func setOffset(_ offset: CGSize) {
        // Calculate the fitted dimensions (how the image appears at scale = 1.0)
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
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
        
        // Scale the fitted dimensions by the current zoom level
        let scaledWidth = fittedWidth * scale
        let scaledHeight = fittedHeight * scale
        
        // Calculate maximum pan distance
        // Simple rule: you can pan as far as needed to see all parts of the scaled image
        let maxOffsetX = max(0, (scaledWidth - containerSize.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - containerSize.height) / 2)
        
        // But allow some minimal panning when zoomed in, even if the scaled image
        // is smaller than the container (this handles the landscape case)
        let finalMaxOffsetX: CGFloat
        let finalMaxOffsetY: CGFloat
        
        if scale > 1.0 {
            // When zoomed, ensure minimum pan range to see different parts of image
            finalMaxOffsetX = max(maxOffsetX, (fittedWidth * (scale - 1.0)) / 2)
            finalMaxOffsetY = max(maxOffsetY, (fittedHeight * (scale - 1.0)) / 2)
        } else {
            finalMaxOffsetX = 0
            finalMaxOffsetY = 0
        }
        
        // Debug logging  
        print("Scale: \(scale)")
        print("Image: \(imageSize.width)x\(imageSize.height), Container: \(containerSize.width)x\(containerSize.height)")
        print("Image aspect: \(imageAspect), Container aspect: \(containerAspect)")
        print("Fitted: \(fittedWidth)x\(fittedHeight)")
        print("Scaled: \(scaledWidth)x\(scaledHeight)")
        print("Max offset: \(finalMaxOffsetX)x\(finalMaxOffsetY)")
        print("Requested offset: \(offset.width)x\(offset.height)")
        print("---")
        
        let clampedOffset = CGSize(
            width: min(max(-finalMaxOffsetX, offset.width), finalMaxOffsetX),
            height: min(max(-finalMaxOffsetY, offset.height), finalMaxOffsetY)
        )
        
        print("Final offset: \(clampedOffset.width)x\(clampedOffset.height)")
        print("===")
        
        _offset = clampedOffset
    }
}
