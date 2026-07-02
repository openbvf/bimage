import Foundation
import ImageIO
import CoreImage

enum ImageEnhanceError: Error {
    case invalidImageData
    case renderFailed(String)
}

enum ImageEnhanceService {
    // GPU-backed context reused across invocations; creating one per call is expensive.
    private static let context = CIContext()

    /// Applies Core Image's content-aware auto-adjust chain (`autoAdjustmentFilters`) to the
    /// pixels of `imageData` and re-encodes in the same format. Operates on raw pixels
    /// (`CGImageSourceCreateImageAtIndex`) and preserves the source EXIF orientation so the
    /// displayed rotation is unchanged.
    ///
    /// Excludes red-eye and face-balance filters — those depend on face detection and can shift
    /// tone unpredictably on non-portrait images.
    static func enhanceImageData(_ imageData: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let uti = CGImageSourceGetType(source) else {
            throw ImageEnhanceError.invalidImageData
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageEnhanceError.invalidImageData
        }

        var image = CIImage(cgImage: cgImage)
        let options: [CIImageAutoAdjustmentOption: Any] = [
            .redEye: false,
            .features: []
        ]
        for filter in image.autoAdjustmentFilters(options: options) {
            filter.setValue(image, forKey: kCIInputImageKey)
            if let output = filter.outputImage {
                image = output
            }
        }

        guard let renderedCG = context.createCGImage(image, from: image.extent) else {
            throw ImageEnhanceError.renderFailed("CIContext render returned nil")
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, uti, 1, nil) else {
            throw ImageEnhanceError.renderFailed("Failed to create destination")
        }

        var properties: [CFString: Any] = [:]
        if let existing = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            properties = existing
        }

        CGImageDestinationAddImage(destination, renderedCG, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageEnhanceError.renderFailed("Failed to finalize destination")
        }

        return mutableData as Data
    }
}
