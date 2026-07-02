import SwiftUI
import AVFoundation
import Combine
import BvfAppKit

struct CameraView: View {
    @Environment(iCloudManager.self) var cloudManager
    @StateObject private var camera = CameraModel()
    @State private var lastSaveDate: Date?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                    } else if let date = lastSaveDate {
                        TimelineView(.periodic(from: Date(), by: 60)) { _ in
                            Text("Saved \(date.relativeTimeString())")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.green.opacity(0.8))
                                .cornerRadius(8)
                        }
                    }
                    Spacer()

                    if camera.hasFrontAndBack {
                        Button(action: { camera.flip() }) {
                            Image(systemName: "camera.rotate")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding()

                Spacer()

                if camera.zoomOptions.count > 1 {
                    HStack {
                        ForEach(camera.zoomOptions, id: \.factor) { option in
                            zoomButton(for: option)
                        }
                    }
                    .padding(.bottom, 20)
                }

                Button(action: capturePhoto) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 80, height: 80)
                        )
                }
                .disabled(camera.isSaving)
                .opacity(camera.isSaving ? 0.5 : 1.0)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            Task {
                if await !AVCaptureDevice.requestAccess(for: .video) {
                    errorMessage = "Camera access denied. Enable in Settings > Privacy & Security > Camera"
                    return
                }
                camera.configure(cloudManager: cloudManager)
                camera.start()
            }
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: camera.lastSaveDate) { _, date in
            lastSaveDate = date
        }
        .onChange(of: camera.errorMessage) { _, error in
            errorMessage = error
        }
    }

    private func capturePhoto() {
        camera.capturePhoto()
    }

    @ViewBuilder
    private func zoomButton(for option: CameraModel.ZoomOption) -> some View {
        let isSelected = abs(camera.currentZoomFactor - option.factor) < 0.01
        if isSelected {
            Button(option.label) { camera.setZoom(factor: option.factor) }
                .buttonStyle(.borderedProminent)
        } else {
            Button(option.label) { camera.setZoom(factor: option.factor) }
                .buttonStyle(.bordered)
        }
    }
}

@MainActor
class CameraModel: NSObject, ObservableObject, @unchecked Sendable {
    struct ZoomOption: Equatable, Hashable {
        let label: String
        let factor: CGFloat
    }

    nonisolated(unsafe) let session = AVCaptureSession()
    private let coordinator = PhotoCaptureCoordinator()
    private var cloudManager: iCloudManager?

    nonisolated(unsafe) private var backDevice: AVCaptureDevice?
    nonisolated(unsafe) private var frontDevice: AVCaptureDevice?
    nonisolated(unsafe) private var currentDevice: AVCaptureDevice?
    nonisolated(unsafe) private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?

    @Published var isSaving = false
    @Published var lastSaveDate: Date?
    @Published var errorMessage: String?
    @Published var zoomOptions: [ZoomOption] = []
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var hasFrontAndBack: Bool = false

    func configure(cloudManager: iCloudManager) {
        self.cloudManager = cloudManager

        coordinator.destinationProvider = { [weak self] in
            guard let self,
                  let cm = self.cloudManager,
                  let folder = cm.appFolderURL,
                  let key = cm.sharedPublicKeyURL else { return nil }
            return PhotoCaptureCoordinator.Destination(folderURL: folder, publicKeyURL: key)
        }
        coordinator.onResult = { [weak self] result in
            guard let self else { return }
            self.isSaving = false
            let generator = UINotificationFeedbackGenerator()
            switch result {
            case .saved:
                self.lastSaveDate = Date()
                self.errorMessage = nil
                generator.notificationOccurred(.success)
            case .failure(let message):
                self.errorMessage = message
                generator.notificationOccurred(.error)
            }
        }

        backDevice = bestDevice(for: .back)
        frontDevice = bestDevice(for: .front)
        hasFrontAndBack = backDevice != nil && frontDevice != nil

        guard let device = backDevice ?? frontDevice else {
            errorMessage = "No camera available"
            return
        }
        activate(device: device)
    }

    /// Prefer a virtual device (triple > dual-wide > dual) so that `virtualDeviceSwitchOverVideoZoomFactors`
    /// gives us the same multipliers the stock Camera app shows; fall back to plain wide.
    private func bestDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let preferred: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        for type in preferred {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [type],
                mediaType: .video,
                position: position
            )
            if let device = discovery.devices.first {
                return device
            }
        }
        return nil
    }

    private func activate(device: AVCaptureDevice) {
        session.beginConfiguration()
        session.sessionPreset = .photo

        for input in session.inputs {
            session.removeInput(input)
        }

        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        if session.outputs.isEmpty, session.canAddOutput(coordinator.output) {
            session.addOutput(coordinator.output)
        }

        currentDevice = device
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)

        session.commitConfiguration()

        zoomOptions = computeZoomOptions(for: device)
        if let wide = zoomOptions.first(where: { $0.label == "1x" }) ?? zoomOptions.first {
            setZoom(factor: wide.factor)
        }
    }

    /// Maps `virtualDeviceSwitchOverVideoZoomFactors` to user-facing multipliers.
    /// Convention: wide lens = 1x, so a multiplier of M corresponds to `videoZoomFactor = M * wideZoom`,
    /// where `wideZoom` is the virtual device's first switch-over factor (i.e., where hardware transitions
    /// from ultra-wide to wide). For non-virtual devices we only expose 1x.
    private func computeZoomOptions(for device: AVCaptureDevice) -> [ZoomOption] {
        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        guard !switchOvers.isEmpty else {
            return [ZoomOption(label: "1x", factor: 1.0)]
        }
        let wideZoom = switchOvers[0]
        var options: [ZoomOption] = []
        options.append(ZoomOption(label: format(1.0 / wideZoom), factor: 1.0))
        options.append(ZoomOption(label: "1x", factor: wideZoom))
        if switchOvers.count > 1 {
            let teleZoom = switchOvers[1]
            let teleMultiplier = teleZoom / wideZoom
            // Only include intermediate 2x when optical telephoto is 3x or more; on 2x-tele phones it'd be redundant.
            if teleMultiplier >= 3.0 {
                options.append(ZoomOption(label: "2x", factor: 2.0 * wideZoom))
            }
            options.append(ZoomOption(label: format(teleMultiplier), factor: teleZoom))
        }
        return options
    }

    private func format(_ multiplier: CGFloat) -> String {
        if multiplier == multiplier.rounded() {
            return "\(Int(multiplier))x"
        } else {
            return String(format: "%.1fx", Double(multiplier))
        }
    }

    func setZoom(factor: CGFloat) {
        guard let device = currentDevice else { return }
        do {
            try device.lockForConfiguration()
            let clamped = max(device.minAvailableVideoZoomFactor,
                              min(device.maxAvailableVideoZoomFactor, factor))
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            currentZoomFactor = clamped
        } catch {
            errorMessage = "Zoom failed: \(error.localizedDescription)"
        }
    }

    func flip() {
        guard let current = currentDevice else { return }
        let target = (current.position == .back) ? frontDevice : backDevice
        if let target {
            activate(device: target)
        }
    }

    func start() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stop() {
        session.stopRunning()
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()

        if let connection = coordinator.output.connection(with: .video),
           let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture,
           connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }

        isSaving = true
        errorMessage = nil
        coordinator.capture(with: settings)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if let connection = uiView.previewLayer.connection,
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }

    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
