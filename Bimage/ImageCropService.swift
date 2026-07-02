import Foundation
import ImageIO
import CoreGraphics

enum ImageCropError: Error {
    case invalidImageData
    case unsupportedFormat
    case cropFailed(String)
}

enum ImageCropService {
    /// Transform a normalized rect based on EXIF orientation
    /// - Parameters:
    ///   - rect: Normalized rect (0-1 coordinates)
    ///   - orientation: EXIF orientation value (1=normal, 3=180°, 6=90°CW, 8=270°CW)
    /// - Returns: Transformed rect
    private static func transformRect(_ rect: CGRect, forOrientation orientation: Int) -> CGRect {
        switch orientation {
        case 1: // Normal
            return rect
        case 3: // 180° rotation
            return CGRect(
                x: 1.0 - rect.maxX,
                y: 1.0 - rect.maxY,
                width: rect.width,
                height: rect.height
            )
        case 6: // 90° CW (270° CCW)
            return CGRect(
                x: rect.minY,
                y: 1.0 - rect.maxX,
                width: rect.height,
                height: rect.width
            )
        case 8: // 270° CW (90° CCW)
            return CGRect(
                x: 1.0 - rect.maxY,
                y: rect.minX,
                width: rect.height,
                height: rect.width
            )
        default:
            return rect
        }
    }

    /// Crop image data given a normalized rect (0-1 coordinates)
    /// - Parameters:
    ///   - imageData: The original image data
    ///   - normalizedRect: CGRect with values from 0 to 1 (origin at top-left)
    /// - Returns: Cropped image data in the same format as input
    static func cropImageData(_ imageData: Data, to normalizedRect: CGRect) throws -> Data {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let uti = CGImageSourceGetType(source) else {
            throw ImageCropError.invalidImageData
        }

        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageCropError.invalidImageData
        }

        var orientation = 1
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let orientationValue = properties[kCGImagePropertyOrientation] as? Int {
            orientation = orientationValue
        }

        let transformedRect = transformRect(normalizedRect, forOrientation: orientation)

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let pixelRect = CGRect(
            x: transformedRect.origin.x * width,
            y: transformedRect.origin.y * height,
            width: transformedRect.width * width,
            height: transformedRect.height * height
        )

        guard let croppedImage = cgImage.cropping(to: pixelRect) else {
            throw ImageCropError.cropFailed("Failed to crop image")
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, uti, 1, nil) else {
            throw ImageCropError.cropFailed("Failed to create destination")
        }

        var properties: [CFString: Any] = [:]
        if let existingProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            properties = existingProperties
        }

        CGImageDestinationAddImage(destination, croppedImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageCropError.cropFailed("Failed to finalize destination")
        }

        return mutableData as Data
    }
}
