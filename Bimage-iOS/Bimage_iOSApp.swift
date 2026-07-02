import SwiftUI
import BvfAppKit

@main
struct Bimage_iOSApp: App {
    @State private var cloudManager = iCloudManager("Bimage", container: "iCloud.io.bvf.shared")

    init() {
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(cloudManager)
                .task {
                    await cloudManager.initialize()
                    StagingManager.recoverOrphanedFiles(to: cloudManager.appFolderURL)
                }
        }
    }
}
