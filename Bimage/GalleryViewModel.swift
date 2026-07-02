import Foundation
import Combine
import AppKit
import BvfAppKitDecrypt

@MainActor
@Observable
class GalleryViewModel: BrowseViewModelBase {
    var failedImages: [URL: String] = [:]
    var selectedDate: Date? {
        didSet {
            if let date = selectedDate {
                selectedDates = [date]
            }
        }
    }
    var imageRotations: [URL: Int] = [:]  // Delta since last persist
    var imageVersion: [URL: Int] = [:]    // Incremented to invalidate views

    @ObservationIgnored private var rotationDebounceTask: Task<Void, Never>?
    @ObservationIgnored private var pendingRotations: Set<URL> = []

    override var itemTypeName: String { "images" }

    init(fileAccessManager: FileAccessManager, appSettings: AppSettings, syncManager: SyncManager) {
        let range = DateRangePreset.last7Days.dateRange()
        super.init(startDate: range.start, endDate: range.end, appSettings: appSettings, fileAccessManager: fileAccessManager, syncManager: syncManager)
    }

    func applyPreset(_ preset: DateRangePreset) {
        let range = preset.dateRange()
        startDate = range.start
        endDate = range.end
    }

    override func populate(from files: [URL]) {
        let imageFiles = files.filter {
            ImageDecryptor.isSupported($0) && !$0.lastPathComponent.hasSuffix(".orig.bvf")
        }
        super.populate(from: imageFiles)
    }

    override func clearSensitiveData(reason: String? = nil) {
        rotationDebounceTask?.cancel()
        pendingRotations.removeAll()
        failedImages.removeAll()
        imageRotations.removeAll()
        imageVersion.removeAll()
        selectedDate = nil
        super.clearSensitiveData(reason: reason)
    }

    func selectImage(date: Date) {
        selectedDate = date
    }

    func dismissFullScreen() {
        selectedDate = nil
    }

    func rotateImage(for url: URL) {
        let current = imageRotations[url] ?? 0
        imageRotations[url] = (current + 90) % 360
        scheduleRotationPersistence(for: url)
    }

    func rotateSelectedImages() {
        var updates: [URL: Int] = [:]
        for date in selectedDates {
            if let url = filesByDate[date] {
                let current = imageRotations[url] ?? 0
                updates[url] = (current + 90) % 360
                scheduleRotationPersistence(for: url)
            }
        }
        imageRotations.merge(updates) { _, new in new }
    }

    private func scheduleRotationPersistence(for url: URL) {
        pendingRotations.insert(url)
        rotationDebounceTask?.cancel()
        rotationDebounceTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            let urls = pendingRotations
            pendingRotations.removeAll()
            for url in urls {
                try? await persistRotation(for: url)
            }
        }
    }

    /// Cancel any debounced rotation for `url` and persist immediately.
    func flushPendingRotation(for url: URL) async {
        rotationDebounceTask?.cancel()
        pendingRotations.remove(url)
        try? await persistRotation(for: url)
    }

    /// Decrypt `url` for a pixel-space edit (crop, enhance). Flushes any pending
    /// rotation first so the returned bytes and the file's EXIF reflect the user's
    /// current view — otherwise a spatial edit would be inverted through the wrong
    /// orientation. All destructive-edit UIs must read source bytes through this,
    /// not through `session.decrypt` directly.
    func readForPixelEdit(url: URL) async throws -> Data {
        await flushPendingRotation(for: url)
        guard let session = session else {
            throw NSError(domain: "GalleryViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No decryption session"])
        }
        return try await session.decrypt(contentsOf: url).data
    }

    func persistRotation(for url: URL) async throws {
        guard session != nil else { return }
        let deltaDegrees = imageRotations[url] ?? 0
        guard deltaDegrees != 0 else { return }

        let decryptedData = try await session!.decrypt(contentsOf: url).data
        let rotatedData = try ImageRotationService.rotateImageData(decryptedData, byDegrees: deltaDegrees)

        try BvfStore.rewrite(data: rotatedData, to: url, publicKeyURL: publicKeyURL!)

        imageRotations.removeValue(forKey: url)
        imageVersion[url, default: 0] += 1
    }

    /// Write pre-computed image bytes to `url` and invalidate any cached decrypted views.
    /// Sole pixel-mutation entry point: flushes any pending rotation delta (defensive —
    /// callers should have used readForPixelEdit which already flushes), preserves the
    /// original sidecar on first edit, and bumps the version so views re-decrypt.
    func rewriteImage(url: URL, with data: Data) async throws {
        guard let publicKeyURL = publicKeyURL else { return }
        await flushPendingRotation(for: url)
        try ImagePair(mainURL: url).preserveOriginal()
        try BvfStore.rewrite(data: data, to: url, publicKeyURL: publicKeyURL)
        imageRotations.removeValue(forKey: url)
        imageVersion[url, default: 0] += 1
    }

    func revert(url: URL) throws {
        try ImagePair(mainURL: url).revert()
        imageRotations.removeValue(forKey: url)
        imageVersion[url, default: 0] += 1
    }

    func hasOriginal(for url: URL) -> Bool {
        ImagePair(mainURL: url).hasOriginal
    }

    /// Delete the .orig.bvf sidecar alongside every main file the super deletes.
    /// Snapshot pairs before super mutates filesByDate; discard originals after.
    override func deleteSelected() async {
        let toDiscard = selectedDates.compactMap { date -> ImagePair? in
            guard let url = filesByDate[date] else { return nil }
            let pair = ImagePair(mainURL: url)
            return pair.hasOriginal ? pair : nil
        }
        await super.deleteSelected()
        for pair in toDiscard where !FileManager.default.fileExists(atPath: pair.mainURL.path) {
            pair.discardOriginal()
        }
    }

    /// Discard the .orig.bvf sidecar at each old location. The sidecar does not follow the
    /// rename — reverting after Change Date is not supported (explicit v1 decision).
    override func changeDate(for dates: Set<Date>, to newDate: Date) async {
        let toDiscard = dates.compactMap { date -> ImagePair? in
            guard let url = filesByDate[date] else { return nil }
            let pair = ImagePair(mainURL: url)
            return pair.hasOriginal ? pair : nil
        }
        await super.changeDate(for: dates, to: newDate)
        for pair in toDiscard where !FileManager.default.fileExists(atPath: pair.mainURL.path) {
            pair.discardOriginal()
        }
    }
}
