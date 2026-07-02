# Privacy

Bimage collects nothing.

There is no analytics, no telemetry, no crash reporting, no advertising identifier, no usage measurement, no remote logging. No data leaves your device for our benefit, because there is no benefit for us to derive. There is no "us" in the operating sense; there is no server, no account system, and no backend.

## Your keys and passphrase

Bimage uses standard public-key encryption. Three things matter:

- **Public key**: encrypts new photos. Safe to share or sync; that's the whole point.
- **Private key**: decrypts photos. Encrypted with your passphrase (locked).
- **Passphrase**: decrypts (unlocks) the private key for viewing.

The keys live on macOS. The public key gets synced to iCloud Drive if you enable it, but the private key never leaves. The passphrase ideally exists only in your head.

## Local-only operation

Bimage never makes a network call. It only reads and writes files on the local device, whether capturing or viewing. If you opt in, cross-device sync (capturing on iOS, or using iCloud Write-Only mode on macOS) encrypts photo files to a local folder which iCloud Drive syncs between devices. iCloud is doing the transport, not Bimage. Your passphrase never leaves your device, and the unlocked private key exists only in memory. Neither the maintainers of Bimage nor Apple can see your photos.

Enhance and crop run entirely on-device through Core Image and ImageIO. Pixels are processed in memory; no image data is sent to any service.

For the cryptographic details, see [BvfKit's SECURITY.md](https://github.com/openbvf/BvfKit/blob/main/SECURITY.md) and the [bvf file format spec](https://github.com/openbvf/bvf/blob/main/SPEC.md).

## What the app reads on your device

Apple requires that apps disclose use of certain system APIs even when no data is transmitted off-device. Bimage uses:

- **Camera**: while the capture screen is open. A preview session runs so you can frame the shot; leaving the tab releases the camera.
- **User defaults** (`UserDefaults`): to remember your preferences and a per-device identifier used to name unsaved drafts so multiple devices don't overwrite each other's work-in-progress.
- **File timestamps**: to detect changes to key files and to group saved photos by date in the browser.

Every read stays on-device. Nothing is reported anywhere.

## What we don't have

- No account.
- No password reset, because there is no password we hold.
- No "your data" page, because there is no data on our side.
- No way to recover a forgotten passphrase. If you forget it, your photos are unrecoverable. This is intentional.

## Third parties

The only third party is Apple, and only if you opt into iCloud Drive sync. Apple's own privacy policy covers iCloud storage. Bimage contacts no other service.

## Changes

This policy is versioned alongside the source at the [Bimage repository](https://github.com/openbvf/bimage). Material changes are noted in release notes.

## Contact

Security disclosures and privacy questions: see [Bimage's SECURITY.md](https://github.com/openbvf/bimage/blob/main/SECURITY.md) for the contact channel. Do not file public issues for security or privacy concerns.
