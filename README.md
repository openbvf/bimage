# Bimage

<img src="bimage-macos.svg" alt="" width="128" align="right">

Bimage is a private app to capture and view photos on macOS. You can also capture from iPhone or iPad. Photos are encrypted as they're captured and decrypted only inside the app where you view them, so there's never a readable copy on disk for Spotlight, backups, other software, or people using your computer to find.

iOS is capture-only by design. An iPhone or iPad can capture new photos but can never view them, because the private key isn't on iOS at all. If your phone is taken, nothing on it is viewable.

Screenshots are on the [App Store listing](https://apps.apple.com/us/app/bimage/id6758463446).

## Features

- Capture and view encrypted photos on macOS.
- Optionally enable iCloud Drive to capture from iPhone or iPad; only your Mac can view.
- Captures straight to an encrypted file. Plaintext photos never touch disk.
- Rotate, crop, and single-tap enhance from inside the viewer; a `.orig.bvf` sidecar preserves the original so destructive edits are revertible.
- Browse by date and filter by tag.
- No lock-in. Everything's a file named by date, decryptable with [bvf-cli](https://github.com/openbvf/bvf/tree/main/bvf-cli); decrypted contents are standard image files.
- Export selection.
- Idle auto-lock.

## Install

<a href="https://apps.apple.com/us/app/bimage/id6758463446?itsct=apps_box_badge&amp;itscg=30200"><img alt="Download on the App Store" src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?releaseDate=1783468800" height="50"></a>

- **macOS**: Requires macOS 15 or later. Or [build from source](BUILDING.md).
- **iOS**: Requires iOS 18 or later.

## First run

You generate keys and choose a passphrase during onboarding. The passphrase is the only thing standing between someone who has your keys and your photos. There is no recovery, no support desk, no "forgot password" link. Ideally it only exists in your head. Make it [secure](https://www.eff.org/dice).

During onboarding, you can also choose to enable iCloud Drive so photos taken on your iPhone or iPad land on your Mac. You can change this later in preferences, where you can also rerun the onboarding wizard at any time.

## What this protects, and what it doesn't

Files at rest are unreadable without your passphrase. Full stop.

For the full threat model and cryptographic details, see [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md).

**Bimage protects you from:**

- Anyone who steals your Mac, iPhone, or iPad
- Someone logged into your Mac as you; passphrase on launch, auto-lock on idle, and can be set to lock the moment focus leaves the app
- Anyone using your iPhone or iPad, which can't view your photos in the first place
- Anyone who copies your encrypted photos; they might see encrypted blobs, never the images
- AI agents, indexers, and other software that read files on your Mac; same answer
- Apple, or anyone who breaches iCloud; same answer

**Bimage does not protect you from:**

- Someone looking over your shoulder while you view a photo, or who films your screen
- A keylogger or a tampered Bimage binary. If your Mac is compromised at runtime, all bets are off.
- A forgotten passphrase. There is no recovery, and the photos are gone.
- A memory attack on your running, unlocked Mac (see [SECURITY.md](SECURITY.md) for the nuances).
- Fake photos from someone using your device. Anyone logged into your Mac, iPhone, or iPad can add a photo.

## Backing up

Your photos are encrypted files; back them up like any other files. An encrypted Time Machine backup doesn't increase exposure meaningfully since the photos are already encrypted, and Time Machine adds a second layer at rest. For remote backup, use a service that lets you supply an encryption key the provider can't access, so a breach of the service doesn't put your photos within reach of someone with your passphrase.

## License

MIT. See [LICENSE](LICENSE).

## Reporting issues

Bugs and feature requests: file an issue at https://github.com/openbvf/bimage/issues.

Security issues: see [SECURITY.md](SECURITY.md). Do not file public issues for security.
