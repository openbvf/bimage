import SwiftUI
import BvfAppKitDecrypt
import UniformTypeIdentifiers

struct GalleryView: View {
    @Environment(FileAccessManager.self) var fileAccessManager
    @Environment(AppSettings.self) var appSettings
    @Environment(SyncManager.self) var syncManager
    @State private var viewModel: GalleryViewModel?

    @State private var showTagSheet = false

    nonisolated func isImageFile(_ url: URL) -> Bool {
        guard let supportedTypes = CGImageSourceCopyTypeIdentifiers() as? [String],
              let fileUTI = UTType(filenameExtension: url.pathExtension) else { return false }
        return supportedTypes.contains(fileUTI.identifier)
    }

    var body: some View {
        Group {
            if let viewModel = viewModel {
                VStack {
                    DateRangeRowView(
                        startDate: Binding(get: { viewModel.startDate }, set: { viewModel.startDate = $0 }),
                        endDate: Binding(get: { viewModel.endDate }, set: { viewModel.endDate = $0 }),
                        selectedPreset: Binding(get: { viewModel.selectedPreset }, set: { viewModel.selectedPreset = $0 }),
                        isReady: viewModel.folderURL != nil && viewModel.publicKeyURL != nil,
                        isLoading: viewModel.isLoading || viewModel.isDecrypting,
                        responseMessage: viewModel.responseMessage,
                        setupErrorMessage: nil,
                        onDecrypt: {
                            await viewModel.loadEntries()
                        }
                    )
                    .browseToolbar(
                        viewModel: viewModel,
                        configuration: BrowseToolbarConfiguration(
                            clearHelpText: "Clear all images",
                            importFileFilter: isImageFile
                        ),
                        showTagSheet: $showTagSheet
                    )

                    ImageGridView(
                        viewModel: viewModel,
                        selectedDates: viewModel.selectedDates,
                        imageRotations: viewModel.imageRotations,
                        imageVersion: viewModel.imageVersion
                    )
                }
                .padding()
                .browseModals(
                    viewModel: viewModel,
                    showTagSheet: $showTagSheet
                )
                .overlay {
                    if viewModel.selectedDate != nil {
                        FullScreenImageView(
                            viewModel: viewModel,
                            selectedDate: viewModel.selectedDate,
                            filteredDates: viewModel.filteredDates,
                            imageRotations: viewModel.imageRotations,
                            imageVersion: viewModel.imageVersion
                        )
                    }
                }
                .background {
                    Button("") { viewModel.rotateSelectedImages() }
                        .keyboardShortcut("r", modifiers: .command)
                        .disabled(viewModel.selectedDates.isEmpty)
                        .hidden()
                }
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = GalleryViewModel(fileAccessManager: fileAccessManager, appSettings: appSettings, syncManager: syncManager)
            }
        }
    }
}
