import Foundation
import ImageIO

enum ImageRotationError: Error {
    case invalidImageData
    case unsupportedFormat
    case rotationFailed(String)
}

enum ImageRotationService {
    /// Maps EXIF orientation to degrees: 1=0°, 6=90°, 3=180°, 8=270°
    private static func degreesFromExif(_ orientation: Int) -> Int {
        switch orientation {
        case 6: return 90
        case 3: return 180
        case 8: return 270
        default: return 0
        }
    }

    /// Maps degrees (0, 90, 180, 270) to EXIF orientation (1=normal, 6=90CW, 3=180, 8=270CW)
    private static func exifOrientation(for degrees: Int) -> Int {
        switch degrees % 360 {
        case 90: return 6
        case 180: return 3
        case 270: return 8
        default: return 1
        }
    }

    /// Read current EXIF orientation as degrees
    static func currentRotation(of imageData: Data) -> Int {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let orientation = properties[kCGImagePropertyOrientation] as? Int else {
            return 0
        }
        return degreesFromExif(orientation)
    }

    /// Modify EXIF orientation without re-encoding pixels
    /// deltaDegrees is ADDED to existing orientation
    static func rotateImageData(_ imageData: Data, byDegrees deltaDegrees: Int) throws -> Data {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let uti = CGImageSourceGetType(source) else {
            throw ImageRotationError.invalidImageData
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, uti, 1, nil) else {
            throw ImageRotationError.rotationFailed("Failed to create destination")
        }

        // Read existing orientation and add delta
        let existingDegrees = currentRotation(of: imageData)
        let newDegrees = (existingDegrees + deltaDegrees) % 360
        let orientation = exifOrientation(for: newDegrees)

        let metadata: CGMutableImageMetadata
        if let existingMetadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil) {
            metadata = CGImageMetadataCreateMutableCopy(existingMetadata) ?? CGImageMetadataCreateMutable()
        } else {
            metadata = CGImageMetadataCreateMutable()
        }

        CGImageMetadataSetValueWithPath(metadata, nil, "tiff:Orientation" as CFString, orientation as CFNumber)

        let options: [CFString: Any] = [
            kCGImageDestinationMetadata: metadata
        ]

        var error: Unmanaged<CFError>?
        guard CGImageDestinationCopyImageSource(destination, source, options as CFDictionary, &error) else {
            throw ImageRotationError.rotationFailed(error?.takeRetainedValue().localizedDescription ?? "Unknown")
        }

        return mutableData as Data
    }
}
