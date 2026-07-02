import SwiftUI
import BvfAppKitDecrypt

struct MainView: View {
    @Environment(FileAccessManager.self) private var fileAccessManager
    @Environment(AppSettings.self) private var appSettings
    @Environment(TabSelection.self) var tabSelection
    @State private var showOnboarding = false

    var body: some View {
        @Bindable var tabSelection = tabSelection
        TabView(selection: $tabSelection.selected) {
            CaptureView()
                .tabItem {
                    Label("Capture", systemImage: "camera")
                }.tag(0)

            // Only show Gallery tab in Standard mode (when local setup is configured)
            if fileAccessManager.isStandardMode {
                GalleryView()
                    .tabItem {
                        Label("Gallery", systemImage: "house.fill")
                    }.tag(1)
            }
        }
        .tabCyclingShortcuts(
            selection: $tabSelection.selected,
            count: fileAccessManager.isStandardMode ? 2 : 1
        )
        .task {
            if !fileAccessManager.isConfigured && !appSettings.hasSkippedOnboarding {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(appName: "Bimage", appGroupIdentifier: "group.io.bvf.shared")
        }
    }
}
