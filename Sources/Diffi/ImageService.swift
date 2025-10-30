import ComposableArchitecture
import Foundation
import SwiftUI

struct ImageService {
    var loadImage: (Data) -> Result<LoadedImage, ImageServiceError>
}

enum ImageServiceError: Error {
    case badData
}

extension ImageService: DependencyKey {
    static var liveValue: Self {
        return Self(
            loadImage: { data in
                guard let nsImage = NSImage(data: data) else {
                    return .failure(.badData)
                }
                return .success(
                    LoadedImage(
                        image: Image(nsImage: nsImage),
                        size: nsImage.size
                    )
                )
            }
        )
    }
}

extension DependencyValues {
    var imageService: ImageService {
        get { self[ImageService.self] }
        set { self[ImageService.self] = newValue }
    }
}
