import Foundation

/// Represents the two-file pair for a single image: the main encrypted file and its optional
/// `.orig.bvf` sidecar that preserves bytes before the first pixel-mutating edit.
struct ImagePair {
    let mainURL: URL

    var originalURL: URL {
        // HH.mm.ss.SSS.jpg.bvf → HH.mm.ss.SSS.jpg.orig.bvf
        let name = mainURL.lastPathComponent  // e.g. "12.34.56.789.jpg.bvf"
        let withoutBvf = (name as NSString).deletingPathExtension  // "12.34.56.789.jpg"
        let origName = withoutBvf + ".orig.bvf"
        return mainURL.deletingLastPathComponent().appendingPathComponent(origName)
    }

    var hasOriginal: Bool {
        FileManager.default.fileExists(atPath: originalURL.path)
    }

    /// Byte-copies main → original iff original doesn't already exist. Idempotent.
    func preserveOriginal() throws {
        let orig = originalURL
        guard !FileManager.default.fileExists(atPath: orig.path) else { return }
        try FileManager.default.copyItem(at: mainURL, to: orig)
    }

    /// Atomic swap via FileManager.replaceItemAt; original is consumed (moved to main).
    func revert() throws {
        _ = try FileManager.default.replaceItemAt(mainURL, withItemAt: originalURL)
    }

    /// Best-effort remove of original. Used after main has been deleted or renamed.
    func discardOriginal() {
        try? FileManager.default.removeItem(at: originalURL)
    }
}
