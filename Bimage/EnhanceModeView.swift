import SwiftUI
import BvfAppKitDecrypt

/// Enhance UI shown as an overlay in `FullScreenImageView`. Runs `ImageEnhanceService` immediately
/// on appear, caches the enhanced bytes, and hands them to `GalleryViewModel.rewriteImage` on
/// Overwrite — so the Metal render doesn't repeat after the user approves the preview.
struct EnhanceModeView: View {
    var viewModel: GalleryViewModel
    var imageURL: URL
    var onFinish: () -> Void

    @State private var previewImage: NSImage?
    @State private var enhancedData: Data?
    @State private var isProcessing: Bool = false
    @State private var loadFailed: Bool = false

    var body: some View {
        ZStack {
            if let preview = previewImage {
                PreviewOverlay(image: preview)
                PreviewOverwriteBar(
                    leftLabel: "Cancel",
                    onLeft: { onFinish() },
                    onOverwrite: overwrite,
                    isProcessing: isProcessing
                )
            } else if loadFailed {
                Color.black.opacity(0.9).ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Enhance failed")
                        .foregroundColor(.white)
                    Button("Close") { onFinish() }
                        .buttonStyle(.bordered)
                }
            } else {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.5)
                    Text("Enhancing…")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
        .task {
            await generatePreview()
        }
    }

    private func generatePreview() async {
        do {
            let decryptedData = try await viewModel.readForPixelEdit(url: imageURL)
            let enhanced = try ImageEnhanceService.enhanceImageData(decryptedData)
            enhancedData = enhanced
            previewImage = NSImage(data: enhanced)
        } catch {
            loadFailed = true
        }
    }

    private func overwrite() {
        guard !isProcessing, let data = enhancedData else { return }
        isProcessing = true
        Task {
            try? await viewModel.rewriteImage(url: imageURL, with: data)
            onFinish()
        }
    }
}
