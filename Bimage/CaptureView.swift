import SwiftUI
import AVFoundation
import BvfAppKitDecrypt

struct CaptureView: View {
    @Environment(FileAccessManager.self) private var fileAccessManager
    @StateObject private var camera = CameraModel()

    private var publicKeyURL: URL? { fileAccessManager.capturePublicKeyURL }
    private var folderURL: URL? { fileAccessManager.captureFolderURL }

    private var isReady: Bool {
        publicKeyURL != nil && folderURL != nil
    }

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
                    .padding(.top, 8)

                Spacer()

                // Capture button
                Button(action: capturePhoto) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)

                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 80, height: 80)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isReady || !camera.isSessionRunning || camera.isSaving)
                .opacity(camera.isSaving ? 0.5 : 1.0)
                .keyboardShortcut(.space, modifiers: [])
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            validateConfiguration()
            camera.setDestination(
                folderURL: folderURL,
                publicKeyURL: publicKeyURL
            )
            Task {
                await camera.setupCamera()
            }
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: folderURL) { _, url in
            validateConfiguration()
            camera.setDestination(folderURL: url, publicKeyURL: publicKeyURL)
        }
        .onChange(of: publicKeyURL) { _, url in
            validateConfiguration()
            camera.setDestination(folderURL: folderURL, publicKeyURL: url)
        }
    }

    private func validateConfiguration() {
        camera.responseMessage = fileAccessManager.validateCaptureConfiguration(folderName: "image folder")
    }

    private var headerView: some View {
        HStack {
            ReadyIndicatorView(isReady: isReady)

            if camera.isConfigured && !camera.isSessionRunning {
                Text("Starting camera...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let message = camera.responseMessage {
                Text(message.text)
                    .font(.caption)
                    .foregroundColor(message.type.color)
                    .lineLimit(2)
            }

            Spacer()

            if camera.availableDevices.count > 1 {
                Picker("Camera", selection: Binding(
                    get: { camera.selectedDeviceUniqueID ?? "" },
                    set: { camera.switchCamera(to: $0) }
                )) {
                    ForEach(camera.availableDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 200)
            }

            Button(action: capturePhoto) {
                Label("Capture", systemImage: "camera")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isReady || !camera.isSessionRunning || camera.isSaving)
            .keyboardShortcut("S", modifiers: .command)
        }
    }

    private func capturePhoto() {
        camera.capturePhoto()
    }
}

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class PreviewView: NSView {
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer = AVCaptureVideoPreviewLayer()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override func layout() {
            super.layout()
            previewLayer.frame = bounds
        }
    }
}
