import SwiftUI
import BvfAppKitDecrypt

struct ImageThumbnailView: View {
    let date: Date
    let url: URL
    let rotation: Int
    let version: Int
    var viewModel: GalleryViewModel
    @State private var showTagPopover = false
    @State private var decryptedImage: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))

            if let nsImage = decryptedImage {
                Image(nsImage: nsImage)
                    .resizable()
                        .aspectRatio(contentMode: .fill)
                    .rotationEffect(.degrees(Double(rotation)))
                    .clipped()
            } else if viewModel.failedImages[url] != nil {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundColor(.red.opacity(0.7))
            } else {
                ProgressView()
            }
        }
        .frame(minWidth: 100, minHeight: 100)
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .bottomTrailing) {
            Text(date.timeString)
                .font(.caption)
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 2)
                .textSelection(.enabled)
                .padding(4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            viewModel.selectImage(date: date)
        }
        .contextMenu {
            Button("Manage Tags") {
                showTagPopover = true
            }
            .disabled(!viewModel.metadataLoaded)
            Button("Rotate") {
                viewModel.rotateSelectedImages()
            }
            .disabled(viewModel.selectedDates.isEmpty)
            Button("Delete") {
                viewModel.showDeleteConfirmation = true
            }
            Button("Change Date...") {
                viewModel.datePickerValue = date
                viewModel.showDatePicker = true
            }
            Button("Export") {
                Task {
                    await viewModel.exportSelected()
                }
            }
            .disabled(viewModel.selectedDates.isEmpty)
        }
        .tagPopover(
            isPresented: $showTagPopover,
            date: date,
            selectedDates: viewModel.selectedDates,
            viewModel: viewModel
        )
        .task(id: "\(url.absoluteString)-\(version)") {
            try? await Task.sleep(for: .milliseconds(BvfAppKitConfig.decryptionDebounceMs))
            guard !Task.isCancelled else { return }

            guard let session = viewModel.session else { return }
            do {
                let image = try await ImageDecryptor.decryptThumbnail(url: url, session: session)
                decryptedImage = image
            } catch is CancellationError {
                // View disappeared - stop
            } catch {
                viewModel.failedImages[url] = error.localizedDescription
            }
        }
    }
}
