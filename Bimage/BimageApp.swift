import SwiftUI
import Combine
import BvfAppKitDecrypt

@main
struct BimageApp: App {
    @State private var tabSelection = TabSelection()
    @State private var env = BvfAppKitEnvironment(
        app: "Bimage",
        container: "iCloud.io.bvf.shared",
        appGroupIdentifier: "group.io.bvf.shared"
    )

    init() {
        DisableCoreDumps.apply()
    }

    var body: some Scene {
        Window("Bimage", id: "main") {
            AppRootView {
                MainView()
                    .environment(tabSelection)
                    .bvfAppKitEnvironment(env)
                    .task {
                        await env.initialize()
                        StagingManager.recoverOrphanedFiles(to: env.cloudManager.appFolderURL)
                    }
            }
        }
        .commands {
            CommandMenu("Tabs") {
                Button("Capture") { tabSelection.selected = 0 }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Gallery") { tabSelection.selected = 1 }
                    .keyboardShortcut("2", modifiers: .command)
            }
        }

        Settings {
            PreferencesView(appName: "Bimage", appGroupIdentifier: "group.io.bvf.shared")
                .bvfAppKitEnvironment(env)
        }
    }
}
