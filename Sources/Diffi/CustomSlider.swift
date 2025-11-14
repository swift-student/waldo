import SwiftUI

// TODO: Clean up, test
struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0.0...1.0

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width
            let thumbPosition = (trackWidth - 20) * (value - range.lowerBound) / (range.upperBound - range.lowerBound)

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.gray.opacity(isEnabled ? 0.3 : 0.1))
                    .frame(height: 6)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .opacity(isEnabled ? 1.0 : 0.3)
                    .shadow(radius: isEnabled ? 1 : 0, y: isEnabled ? 1 : 0)
                    .overlay(
                        Circle().stroke(Color.gray.opacity(0.5), lineWidth: isEnabled ? 0 : 2)
                    )
                    .frame(width: 20, height: 20)
                    .offset(x: thumbPosition)
                    .gesture(
                        isEnabled ?
                            DragGesture(minimumDistance: 0)
                                .onChanged { gestureValue in
                                    updateValue(with: gestureValue.location.x, in: trackWidth)
                                }
                            : nil
                    )
            }
            .frame(height: 20)
        }
        .frame(height: 20)
    }

    private func updateValue(with location: CGFloat, in width: CGFloat) {
        let thumbRadius = 10.0
        let effectiveWidth = width - (thumbRadius * 2)
        
        let dragLocation = max(0, min(location - thumbRadius, effectiveWidth))
        
        let percentage = dragLocation / effectiveWidth
        
        let newValue = (range.upperBound - range.lowerBound) * percentage + range.lowerBound
        let clampedValue = max(range.lowerBound, min(range.upperBound, newValue))
        value = clampedValue
    }
}
