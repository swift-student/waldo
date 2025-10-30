import AppKit

func makeTempDir() throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    return tempDir
}

func createDummyImageData(color: NSColor, size: NSSize) throws -> Data {
    let imageRep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!

    let context = NSGraphicsContext(bitmapImageRep: imageRep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    color.setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = imageRep.representation(using: .png, properties: [:]) else {
        struct ImageDataError: Error {}
        throw ImageDataError()
    }
    return data
}
