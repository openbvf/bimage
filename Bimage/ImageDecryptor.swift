import Foundation
import AppKit
import BvfAppKitDecrypt

enum ImageDecryptionError: Error {
    case emptyFile
    case invalidImageData
    case decryptionFailed(String)
}

enum ImageDecryptor {
    /// Full-size decode that honors EXIF orientation. We route through the thumbnail path with
    /// an unbounded max size because `kCGImageSourceCreateThumbnailWithTransform` is the only
    /// option that applies EXIF rotation at decode time; `CGImageSourceCreateImageAtIndex` does not.
    static func decryptImageWithTransform(url: URL, session: DecryptionSession) async throws -> NSImage {
        try await decodeImage(url: url, session: session, maxSize: CGFloat(Int.max))
    }

    static func decryptThumbnail(url: URL, session: DecryptionSession, maxSize: CGFloat = 300) async throws -> NSImage {
        try await decodeImage(url: url, session: session, maxSize: maxSize)
    }

    private static func decodeImage(url: URL, session: DecryptionSession, maxSize: CGFloat?) async throws -> NSImage {
        try await session.decryptAndTransform(contentsOf: url) { data in
            guard !data.isEmpty else {
                throw ImageDecryptionError.emptyFile
            }

            let options: [CFString: Any]
            if let maxSize {
                options = [
                    kCGImageSourceShouldCache: false,
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxSize,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ]
            } else {
                options = [kCGImageSourceShouldCache: false]
            }

            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                throw ImageDecryptionError.invalidImageData
            }

            let cgImage: CGImage?
            if maxSize != nil {
                cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            } else {
                cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary)
            }

            guard let cgImage else {
                throw ImageDecryptionError.invalidImageData
            }

            return NSImage(cgImage: cgImage, size: .zero)
        }
    }

    /// Check if file is a .bvf file (all .bvf files in Bimage folder are images)
    static func isSupported(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "bvf"
    }
}
