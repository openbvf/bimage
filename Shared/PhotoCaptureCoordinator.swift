import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import BvfAppKit

/// Owns the AVCapturePhotoOutput and the glue that turns a captured photo into an
/// encrypted file on disk. Callers provide the destination lazily so this class doesn't
/// need to know about iCloudManager (iOS) vs FileAccessManager (macOS).
///
/// The delegate callback fires on an unspecified queue; results hop to MainActor
/// before invoking `onResult`.
final class PhotoCaptureCoordinator: NSObject {
    struct Destination: Sendable {
        let folderURL: URL
        let publicKeyURL: URL
    }

    enum CaptureResult: Sendable {
        case saved
        case failure(String)
    }

    let output = AVCapturePhotoOutput()

    var destinationProvider: (() -> Destination?)?
    var onResult: ((CaptureResult) -> Void)?

    override init() {
        super.init()
    }

    func capture(with settings: AVCapturePhotoSettings) {
        output.capturePhoto(with: settings, delegate: self)
    }

    nonisolated static func suffixForImageData(_ data: Data) -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let uti = CGImageSourceGetType(source) as String? else {
            return "jpg"
        }
        switch uti {
        case "public.heic", "public.heif": return "heic"
        case "public.jpeg": return "jpg"
        case "public.png": return "png"
        case "com.adobe.raw-image": return "dng"
        default: return UTType(uti)?.preferredFilenameExtension ?? "jpg"
        }
    }
}

extension PhotoCaptureCoordinator: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            let message = "Capture failed: \(error.localizedDescription)"
            Task { @MainActor in self.onResult?(.failure(message)) }
            return
        }
        guard let imageData = photo.fileDataRepresentation() else {
            Task { @MainActor in self.onResult?(.failure("Failed to get image data")) }
            return
        }
        let suffix = Self.suffixForImageData(imageData)
        Task { @MainActor in
            await self.performSave(data: imageData, suffix: suffix)
        }
    }

    @MainActor
    private func performSave(data: Data, suffix: String) async {
        guard let destination = destinationProvider?() else {
            onResult?(.failure("Destination not configured"))
            return
        }
        do {
            _ = try await BvfStore.write(
                data: data,
                to: destination.folderURL,
                publicKeyURL: destination.publicKeyURL,
                suffix: suffix
            )
            onResult?(.saved)
        } catch {
            onResult?(.failure("Save failed: \(error.localizedDescription)"))
        }
    }
}
