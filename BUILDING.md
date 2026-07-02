# Building from source

> This section written by an LLM and untested.

Bimage is signed and provisioned against a specific Apple Developer team, so a fresh clone won't build as-is. To build locally, swap five identifiers for your own. The first four are in Xcode and config files; the fifth is in Swift source. Miss the fifth and the app will compile, sign, and launch, but read and write to the wrong iCloud container and app group at runtime.

1. **Team ID**: open `Bimage.xcodeproj`, select the *Bimage* project at the project navigator root, and under *Signing & Capabilities* change the team to yours. (This rewrites `DEVELOPMENT_TEAM` in `Bimage.xcodeproj/project.pbxproj`.)
2. **Bundle identifier**: both targets ship as `io.bvf.bimage[.debug]`. Change to your own reverse-DNS prefix in the same *Signing & Capabilities* tab.
3. **iCloud container**: `Bimage/Bimage.entitlements` (macOS) and `Bimage-iOS/Bimage-iOS.entitlements` (iOS) list `iCloud.io.bvf.shared`. Replace with a container in your team.
4. **App group**: the macOS entitlements file also lists `group.io.bvf.shared`. Replace with one in your team.
5. **Swift source**: the same `iCloud.io.bvf.shared` and `group.io.bvf.shared` strings also appear in `Bimage/BimageApp.swift` (the `BvfAppKitEnvironment` initializer and the `PreferencesView` call), `Bimage/MainView.swift` (the `OnboardingView` call), and `Bimage-iOS/Bimage_iOSApp.swift` (the `iCloudManager` initializer). Replace each with the same identifiers you used in steps 3 and 4. `grep -r "io.bvf.shared"` will catch any stragglers.

iCloud containers and app groups require a paid Apple Developer account. On a free Personal Team, remove the iCloud and App Group capabilities in *Signing & Capabilities*, and adjust the Swift code in step 5 so it doesn't try to initialize them. The app will build and run as a local-only gallery but won't sync across devices.

Then: `xcodebuild -scheme Bimage -configuration Debug -destination 'platform=macOS'`, or open in Xcode and Run.
