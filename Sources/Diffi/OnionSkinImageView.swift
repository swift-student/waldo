import SwiftUI

struct OnionSkinImageView: View {
    let previousVersionState: ImageLoadState?
    let currentVersionState: ImageLoadState?
    let blend: Double
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
                .opacity(blend)
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
        case (nil, .loaded):
            ImageVersionView(
                state: currentVersionState,
                zoomPanState: zoomPanState
            )
        case (.loaded, nil):
            ImageVersionView(
                state: previousVersionState,
                zoomPanState: zoomPanState
            )
        case (.loaded, .deleted):
            ImageVersionView(
                state: previousVersionState,
                zoomPanState: zoomPanState,
                isDeleted: true
            )
        default:
            EmptyView()
        }
    }
}


