import SwiftUI
import BvfAppKitDecrypt

/// Defers a @Published mutation to avoid "Publishing changes from within view updates" warnings
private func deferPublish(_ action: @escaping @MainActor () -> Void) {
    Task { @MainActor in action() }
}

struct FullScreenImageView: View {
    var viewModel: GalleryViewModel
    var selectedDate: Date?
    var filteredDates: [Date]
    var imageRotations: [URL: Int]
    var imageVersion: [URL: Int]
    @FocusState private var isFocused: Bool
    @State private var decryptedImage: NSImage?
    @State private var cropMode: Bool = false
    @State private var enhanceMode: Bool = false
    @State private var isEnteringMode: Bool = false
    @State private var hasOriginal: Bool = false
    @State private var showRevertConfirmation: Bool = false

    private var currentImageURL: URL? {
        guard let date = selectedDate else { return nil }
        return viewModel.filesByDate[date]
    }

    /// Read rotation from the view model so it stays in sync when persistRotation
    /// clears the delta (otherwise the local state would combine with the just-baked
    /// EXIF to double-rotate).
    private var rotationDegrees: Int {
        guard let url = currentImageURL else { return 0 }
        return imageRotations[url] ?? 0
    }

    private var isInDestructiveMode: Bool { cropMode || enhanceMode }

    private func imageFrame(imageSize: CGSize, in viewSize: CGSize) -> CGRect {
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        if imageAspect > viewAspect {
            let width = viewSize.width
            let height = width / imageAspect
            let y = (viewSize.height - height) / 2
            return CGRect(x: 0, y: y, width: width, height: height)
        } else {
            let height = viewSize.height
            let width = height * imageAspect
            let x = (viewSize.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: height)
        }
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let date = selectedDate,
               let _ = viewModel.filesByDate[date] {
                if let nsImage = decryptedImage {
                    GeometryReader { geometry in
                        let imgFrame = imageFrame(imageSize: nsImage.size, in: geometry.size)
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .rotationEffect(.degrees(Double(rotationDegrees)))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .overlay {
                                if cropMode, let url = currentImageURL {
                                    CropModeView(
                                        viewModel: viewModel,
                                        imageURL: url,
                                        imageFrame: imgFrame,
                                        onFinish: { cropMode = false }
                                    )
                                } else if enhanceMode, let url = currentImageURL {
                                    EnhanceModeView(
                                        viewModel: viewModel,
                                        imageURL: url,
                                        onFinish: { enhanceMode = false }
                                    )
                                }
                            }
                    }
                } else if let url = currentImageURL, let errorMessage = viewModel.failedImages[url] {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Failed to load image")
                            .font(.headline)
                            .foregroundColor(.white)
                        if let date = selectedDate {
                            Text(date.formatted(date: .abbreviated, time: .standard))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .textSelection(.enabled)
                    }
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }

            if !isInDestructiveMode, decryptedImage != nil {
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Button(action: { enterDestructiveMode { cropMode = true } }) {
                                Image(systemName: "crop")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isEnteringMode)

                            Button(action: { enterDestructiveMode { enhanceMode = true } }) {
                                Image(systemName: "wand.and.stars")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isEnteringMode)

                            if hasOriginal {
                                Button(action: { showRevertConfirmation = true }) {
                                    Image(systemName: "arrow.uturn.backward.circle")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .disabled(isEnteringMode)
                                .confirmationDialog(
                                    "Revert to original?",
                                    isPresented: $showRevertConfirmation,
                                    titleVisibility: .visible
                                ) {
                                    Button("Revert", role: .destructive) {
                                        if let url = currentImageURL {
                                            try? viewModel.revert(url: url)
                                            hasOriginal = false
                                        }
                                    }
                                    Button("Cancel", role: .cancel) {}
                                } message: {
                                    Text("This will discard all crop and enhance edits. It cannot be undone.")
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isInDestructiveMode {
                viewModel.dismissFullScreen()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    guard !isInDestructiveMode else { return }
                    let horizontal = value.translation.width
                    if abs(horizontal) > abs(value.translation.height) {
                        if horizontal < 0, let date = selectedDate,
                           let idx = filteredDates.firstIndex(of: date),
                           idx < filteredDates.count - 1 {
                            viewModel.selectedDate = filteredDates[idx + 1]
                        } else if horizontal > 0, let date = selectedDate,
                                  let idx = filteredDates.firstIndex(of: date),
                                  idx > 0 {
                            viewModel.selectedDate = filteredDates[idx - 1]
                        }
                    }
                }
        )
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress { press in
            switch press.key {
            case .leftArrow:
                guard !isInDestructiveMode else { return .ignored }
                if let date = selectedDate,
                   let idx = filteredDates.firstIndex(of: date),
                   idx > 0 {
                    deferPublish { viewModel.selectedDate = filteredDates[idx - 1] }
                }
                return .handled
            case .rightArrow:
                guard !isInDestructiveMode else { return .ignored }
                if let date = selectedDate,
                   let idx = filteredDates.firstIndex(of: date),
                   idx < filteredDates.count - 1 {
                    deferPublish { viewModel.selectedDate = filteredDates[idx + 1] }
                }
                return .handled
            case .escape:
                if cropMode {
                    deferPublish { cropMode = false }
                } else if enhanceMode {
                    deferPublish { enhanceMode = false }
                } else {
                    deferPublish { viewModel.dismissFullScreen() }
                }
                return .handled
            default:
                if press.characters == "r" && press.modifiers.contains(.command) {
                    guard !isInDestructiveMode else { return .ignored }
                    if let url = currentImageURL {
                        deferPublish { viewModel.rotateImage(for: url) }
                    }
                    return .handled
                }
                return .ignored
            }
        }
        .onAppear {
            isFocused = true
        }
        .onChange(of: isFocused) { _, newValue in
            if !newValue && selectedDate != nil {
                isFocused = true
            }
        }
        .onChange(of: selectedDate) { _, _ in
            decryptedImage = nil
        }
        .task(id: "\(selectedDate?.timeIntervalSince1970 ?? 0)-\(currentImageURL.map { imageVersion[$0] ?? 0 } ?? 0)") {
            guard let session = viewModel.session,
                  let date = selectedDate,
                  let url = viewModel.filesByDate[date] else { return }
            do {
                let image = try await ImageDecryptor.decryptImageWithTransform(url: url, session: session)
                decryptedImage = image
                hasOriginal = viewModel.hasOriginal(for: url)
                viewModel.failedImages.removeValue(forKey: url)
            } catch {
                viewModel.failedImages[url] = error.localizedDescription
            }
        }
    }

    /// Flush and re-decrypt before activating a pixel-editing mode so the display image
    /// under the crop/enhance overlay stays visually consistent — without this, clearing
    /// the rotation delta would briefly show the un-rotated pixels before the .task
    /// re-decodes the newly-baked EXIF. Correctness (source EXIF matches user view at
    /// edit time) is enforced separately by `readForPixelEdit`.
    private func enterDestructiveMode(activate: @escaping () -> Void) {
        guard !isEnteringMode, let url = currentImageURL else { return }
        let pendingDelta = imageRotations[url] ?? 0
        if pendingDelta == 0 {
            activate()
            return
        }
        isEnteringMode = true
        Task {
            await viewModel.flushPendingRotation(for: url)
            if let session = viewModel.session,
               let image = try? await ImageDecryptor.decryptImageWithTransform(url: url, session: session) {
                decryptedImage = image
            }
            isEnteringMode = false
            activate()
        }
    }
}
