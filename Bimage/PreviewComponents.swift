import SwiftUI

/// Full-screen darkened preview of a decrypted, transformed image. Shared by crop and enhance
/// modes so the visual language stays identical across destructive-overwrite flows.
struct PreviewOverlay: View {
    let image: NSImage

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Bottom action bar used by every destructive-overwrite preview. Left button varies ("Back" to
/// return to an editing state, "Cancel" to abandon); right button is always the destructive
/// "Overwrite".
struct PreviewOverwriteBar: View {
    let leftLabel: String
    let onLeft: () -> Void
    let onOverwrite: () -> Void
    let isProcessing: Bool

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                Button(leftLabel, action: onLeft)
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
                Button("Overwrite", action: onOverwrite)
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)
            }
            .padding(.bottom, 40)
        }
    }
}
