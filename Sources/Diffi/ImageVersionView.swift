import SwiftUI

struct ImageVersionView: View {
    let state: ImageLoadState?
    @Bindable var zoomPanState: ZoomPanState
    var isDeleted: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(isDeleted ? 0.3 : 1.0)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView("Loading...")
        case let .loaded(loadedImage):
            ZoomableImageView(image: loadedImage.image, imageSize: loadedImage.size, zoomPanState: zoomPanState)
        case .error(let error):
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))

                Text("Could not load image")
                    .foregroundColor(.secondary)
                Text(error.debugDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .deleted, .none:
            EmptyView()
        }
    }
}
