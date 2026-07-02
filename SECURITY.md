# Security

Bimage is a thin SwiftUI shell on [BvfAppKit](https://github.com/openbvf/BvfAppKit). This file covers only what's specific to capturing-and-viewing-photos.

## Reporting vulnerabilities

If you find a security issue, **do not open a public issue.** Instead:

- **GitHub Security Advisories** (preferred): [Submit a private advisory](https://github.com/openbvf/bimage/security/advisories/new)
- **Email**: bvf@newvoll.net

## Out of scope

- App-lifecycle surface: [BvfAppKit/SECURITY.md](https://github.com/openbvf/BvfAppKit/blob/main/SECURITY.md).
- Encryption, key derivation, libsodium interop: [BvfKit/SECURITY.md](https://github.com/openbvf/BvfKit/blob/main/SECURITY.md).
- The `.bvf` file format and its threat model: [bvf/SECURITY.md](https://github.com/openbvf/bvf/blob/main/SECURITY.md).

## In scope

### Plaintext pixels in memory during capture and editing

Pixels pass through memory between the camera and the encryption stream during capture, and between decrypt and re-encrypt during crop, enhance, and rotate. They have to, since image encoding happens before the bytes hit the encrypted file. The window is short — a single frame at capture time, or the decoded image at edit time — and nothing is persisted in cleartext on disk along the way. A memory attack on the running, unlocked process could observe these buffers; the mitigation is the same as for any decrypted content held in a running app: keep the device under your control while using it, and lock the app when you walk away.

### Camera-active indicator while the capture screen is open

The camera preview session runs the moment you open the capture screen, before you tap the shutter, so you can frame the shot. Consequence: the system camera-in-use indicator (the green dot on iOS, the menu-bar indicator on macOS) lights up while the capture screen is visible even when you aren't actively taking a photo. Leaving the tab tears the session down and releases the camera.

### Revert-to-original sidecar

Crop and enhance overwrite the encrypted file in place, but the original bytes are preserved as an encrypted `.orig.bvf` sidecar next to the file so you can revert. If you don't want the original retained, delete the sidecar manually (or the whole file). The sidecar is encrypted with the same public key as the file it accompanies.

### Fake photos via iCloud

If you've enabled iCloud sync and your iCloud account is compromised, an adversary can write `.bvf` files into your photo folder. Bimage will sync them down and present them as photos. There is no per-file signature today that lets you distinguish your own writes from injected ones; the cryptographic guarantee is confidentiality of contents, not authenticity of authorship. Mitigation: protect your iCloud account.

### Public key substitution via iCloud

If you've enabled iCloud sync, Bimage publishes your public key to a shared iCloud location so iOS captures can encrypt to it. An adversary who can write to that location could swap your key with their own; subsequent iOS captures would encrypt to the adversary's key and be readable by them. BvfAppKit's `PubkeyDistributor` watches that location and surfaces a mismatch when the remote key diverges from the local one. See [BvfAppKit/SECURITY.md](https://github.com/openbvf/BvfAppKit/blob/main/SECURITY.md) for the mechanism.
