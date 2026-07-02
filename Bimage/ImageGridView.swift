import SwiftUI
import BvfAppKitDecrypt

struct ImageGridView: View {
    var viewModel: GalleryViewModel
    var selectedDates: Set<Date>
    var imageRotations: [URL: Int]
    var imageVersion: [URL: Int]

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(viewModel.groupedDates, id: \.day) { group in
                    Section {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(group.dates, id: \.self) { date in
                                if let url = viewModel.filesByDate[date] {
                                    ImageThumbnailView(
                                        date: date,
                                        url: url,
                                        rotation: imageRotations[url] ?? 0,
                                        version: imageVersion[url] ?? 0,
                                        viewModel: viewModel
                                    )
                                    .selectableItem(date: date, isSelected: selectedDates.contains(date)) {
                                        viewModel.handleSelection(date, in: viewModel.filteredDates)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    } header: {
                        Text(group.day.dayWithWeekdayString)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                            .background(.background)
                    }
                }
            }
        }
    }
}
