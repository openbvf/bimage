import SwiftUI
import BvfAppKitDecrypt

/// Crop UI shown as an overlay in `FullScreenImageView`. Owns its own cropRect and preview state,
/// and routes through `GalleryViewModel.rewriteImage` on Overwrite — matching EnhanceModeView's
/// caching pattern so the crop doesn't re-run after the user approves the preview.
struct CropModeView: View {
    var viewModel: GalleryViewModel
    var imageURL: URL
    var imageFrame: CGRect
    var onFinish: () -> Void

    @State private var cropRect: CGRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    @State private var croppedData: Data?
    @State private var previewImage: NSImage?
    @State private var isProcessing: Bool = false

    var body: some View {
        ZStack {
            if let preview = previewImage {
                PreviewOverlay(image: preview)
                PreviewOverwriteBar(
                    leftLabel: "Back",
                    onLeft: { previewImage = nil },
                    onOverwrite: overwrite,
                    isProcessing: isProcessing
                )
            } else {
                CropOverlayView(cropRect: $cropRect, imageFrame: imageFrame)
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Button("Cancel") { onFinish() }
                            .buttonStyle(.bordered)
                        Button("Apply") { showPreview() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func showPreview() {
        Task {
            do {
                let decryptedData = try await viewModel.readForPixelEdit(url: imageURL)
                let data = try ImageCropService.cropImageData(decryptedData, to: cropRect)
                croppedData = data
                previewImage = NSImage(data: data)
            } catch {
                // Preview failed; leave user in crop mode so they can try again.
            }
        }
    }

    private func overwrite() {
        guard !isProcessing, let data = croppedData else { return }
        isProcessing = true
        Task {
            try? await viewModel.rewriteImage(url: imageURL, with: data)
            onFinish()
        }
    }
}
