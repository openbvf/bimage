import AVFoundation
import AppKit
import Combine
import BvfAppKitDecrypt

final class CameraModel: NSObject, ObservableObject, @unchecked Sendable {
    nonisolated(unsafe) let session = AVCaptureSession()
    private let coordinator = PhotoCaptureCoordinator()
    nonisolated(unsafe) private var folderURL: URL?
    nonisolated(unsafe) private var publicKeyURL: URL?

    @Published var isConfigured = false
    @Published var isSessionRunning = false
    @Published var isSaving = false
    @Published var responseMessage: ResponseMessage?
    @Published var availableDevices: [AVCaptureDevice] = []
    @Published var selectedDeviceUniqueID: String?

    private var sessionRunningObservation: NSKeyValueObservation?

    override init() {
        super.init()
        coordinator.destinationProvider = { [weak self] in
            guard let self,
                  let folder = self.folderURL,
                  let key = self.publicKeyURL else { return nil }
            return PhotoCaptureCoordinator.Destination(folderURL: folder, publicKeyURL: key)
        }
        coordinator.onResult = { [weak self] result in
            guard let self else { return }
            self.isSaving = false
            switch result {
            case .saved:
                self.responseMessage = ResponseMessage("Saved at \(Date().timeString)", type: .success)
            case .failure(let message):
                self.responseMessage = ResponseMessage(message, type: .error)
            }
        }
    }

    func setupCamera() async {
        if isConfigured {
            start()
            return
        }

        guard session.inputs.isEmpty else { return }

        if await !AVCaptureDevice.requestAccess(for: .video) {
            await MainActor.run {
                responseMessage = ResponseMessage("Camera access denied. Enable in System Settings > Privacy & Security > Camera", type: .error)
            }
            return
        }

        configureSession()
    }

    func setDestination(folderURL: URL?, publicKeyURL: URL?) {
        self.folderURL = folderURL
        self.publicKeyURL = publicKeyURL
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )

        let devices = discoverySession.devices
        guard let device = devices.first else {
            responseMessage = ResponseMessage("No camera found. Available devices: \(devices.count)", type: .error)
            session.commitConfiguration()
            return
        }

        availableDevices = devices
        selectedDeviceUniqueID = device.uniqueID

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                responseMessage = ResponseMessage("Cannot add camera input to session", type: .error)
                session.commitConfiguration()
                return
            }
        } catch {
            responseMessage = ResponseMessage("Camera input error: \(error.localizedDescription)", type: .error)
            session.commitConfiguration()
            return
        }

        if session.canAddOutput(coordinator.output) {
            session.addOutput(coordinator.output)
        }

        session.commitConfiguration()
        isConfigured = true

        sessionRunningObservation = session.observe(\.isRunning, options: [.new]) { [weak self] _, change in
            guard let self = self, let isRunning = change.newValue else { return }
            Task { @MainActor in
                self.isSessionRunning = isRunning
            }
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func start() {
        guard isConfigured else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stop() {
        session.stopRunning()
    }

    func switchCamera(to uniqueID: String) {
        guard isConfigured, uniqueID != selectedDeviceUniqueID else { return }
        guard let device = availableDevices.first(where: { $0.uniqueID == uniqueID }) else { return }

        session.beginConfiguration()
        for input in session.inputs {
            if let deviceInput = input as? AVCaptureDeviceInput, deviceInput.device.hasMediaType(.video) {
                session.removeInput(deviceInput)
            }
        }

        do {
            let newInput = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                selectedDeviceUniqueID = uniqueID
            } else {
                responseMessage = ResponseMessage("Cannot switch to selected camera", type: .error)
            }
        } catch {
            responseMessage = ResponseMessage("Camera switch error: \(error.localizedDescription)", type: .error)
        }
        session.commitConfiguration()
    }

    func capturePhoto() {
        guard isConfigured, isSessionRunning else { return }
        isSaving = true
        coordinator.capture(with: AVCapturePhotoSettings())
    }
}
