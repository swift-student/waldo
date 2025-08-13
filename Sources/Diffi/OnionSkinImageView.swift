import SwiftUI

struct OnionSkinImageView: View {
    let previousVersionState: ImageLoadState?
    let currentVersionState: ImageLoadState?
    let opacityBlend: Double
    let previousVersionTitle: String
    let currentVersionTitle: String
    @Bindable var zoomPanState: ZoomPanState
    let onOpacityChanged: (Double) -> Void

    var body: some View {
        VStack {
            imageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        switch (previousVersionState, currentVersionState) {
        case (.loading, _), (_, .loading):
            ProgressView("Loading...")
        case let (.loaded(previousImage), .loaded(currentImage)):
            VStack {
                ZStack {
                    ZoomableImageView(
                        image: previousImage.image,
                        imageSize: previousImage.size,
                        zoomPanState: zoomPanState
                    )

                    ZoomableImageView(
                        image: currentImage.image,
                        imageSize: currentImage.size,
                        zoomPanState: zoomPanState
                    )
                    .opacity(opacityBlend)
                }
                OpacitySliderView(
                    value: opacityBlend,
                    previousTitle: previousVersionTitle,
                    currentTitle: currentVersionTitle,
                    onValueChanged: onOpacityChanged
                )
                .padding(.horizontal)
            }
        case let (.error(error), _), let (_, .error(error)):
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))

                Text("Could not load image")
                    .foregroundColor(.secondary)
                Text(error.debugDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case (nil, let .loaded(currentImage)):
            ZoomableImageView(
                image: currentImage.image,
                imageSize: currentImage.size,
                zoomPanState: zoomPanState
            )
        case (.loaded(let previousImage), nil):
            ZoomableImageView(
                image: previousImage.image,
                imageSize: previousImage.size,
                zoomPanState: zoomPanState
            )
        default:
            EmptyView()
        }
    }
}

struct OpacitySliderView: View {
    let value: Double
    let previousTitle: String
    let currentTitle: String
    let onValueChanged: (Double) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(previousTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(currentTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Slider(value: Binding(
                get: { value },
                set: onValueChanged
            ), in: 0.0 ... 1.0)
        }
    }
}

