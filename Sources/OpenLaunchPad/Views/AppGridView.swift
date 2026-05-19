import SwiftUI

enum AppGridMode {
    case paged
    case scrolling
}

struct AppGridLayout {
    let columnCount: Int
    let cellWidth: CGFloat
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat
    let contentWidth: CGFloat
    let viewportHeight: CGFloat

    init(size: CGSize, iconSize: CGFloat, requestedColumns: Int) {
        let horizontalPadding = min(max(size.width * 0.06, 24), 120)
        let availableWidth = max(size.width - horizontalPadding * 2, iconSize)
        let cellWidth = iconSize + 40
        let minimumSpacing: CGFloat = 24
        let fittingColumns = max(1, Int((availableWidth + minimumSpacing) / (cellWidth + minimumSpacing)))
        let preferredColumns = requestedColumns > 0 ? requestedColumns : fittingColumns
        let columnCount = min(preferredColumns, fittingColumns)
        let naturalSpacing = columnCount > 1
            ? (availableWidth - CGFloat(columnCount) * cellWidth) / CGFloat(columnCount - 1)
            : 0
        let columnSpacing = columnCount > 1 ? min(max(naturalSpacing, minimumSpacing), 96) : 0

        self.columnCount = columnCount
        self.cellWidth = cellWidth
        self.columnSpacing = columnSpacing
        self.rowSpacing = min(max(size.height * 0.04, 24), 48)
        self.contentWidth = CGFloat(columnCount) * cellWidth + CGFloat(max(columnCount - 1, 0)) * columnSpacing
        self.viewportHeight = size.height
    }

    func contentHeight(itemCount: Int) -> CGFloat {
        guard itemCount > 0 else { return 0 }
        let rowCount = Int(ceil(Double(itemCount) / Double(columnCount)))
        return CGFloat(rowCount) * cellWidth + CGFloat(max(rowCount - 1, 0)) * rowSpacing
    }
}

/// Paginated grid of app icons and folders.
struct AppGridView: View {
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(ConfigStore.self) private var config
    let mode: AppGridMode
    private let onLaunch: ((AppItem) -> Void)?

    init(mode: AppGridMode = .paged, onLaunch: ((AppItem) -> Void)? = nil) {
        self.mode = mode
        self.onLaunch = onLaunch
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = AppGridLayout(
                size: proxy.size,
                iconSize: config.iconSize,
                requestedColumns: config.gridColumns
            )

            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(pageSwipeGesture)

                if vm.isLoading {
                    ProgressView()
                } else if let error = vm.loadError {
                    Text(error)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                } else if vm.pages.isEmpty {
                    Text("No applications found")
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    switch mode {
                    case .paged:
                        pagedGrid(layout: layout)
                    case .scrolling:
                        scrollingGrid(layout: layout)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.22 * config.animationSpeed), value: vm.currentPage)
        }
    }

    private func pagedGrid(layout: AppGridLayout) -> some View {
        ZStack {
            itemGrid(items: currentPageItems, layout: layout)
                .frame(
                    minHeight: max(
                        layout.viewportHeight - 48,
                        layout.contentHeight(itemCount: currentPageItems.count)
                    ),
                    alignment: .center
                )
                .id(currentPageIndex)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .simultaneousGesture(pageSwipeGesture)
                .dropDestination(for: AppItem.self) { dropped, _ in
                    guard let app = dropped.first else { return false }
                    vm.move(itemID: app.id, toPage: currentPageIndex, at: currentPageItems.count)
                    return true
                }

            HorizontalPageScrollMonitor(
                onPrevious: vm.showPreviousPage,
                onNext: vm.showNextPage
            )
            .frame(width: 0, height: 0)
        }
    }

    private func scrollingGrid(layout: AppGridLayout) -> some View {
        ScrollView(.vertical) {
            itemGrid(items: vm.pages.flatMap { $0 }, layout: layout)
                .padding(.vertical, 24)
        }
        .scrollIndicators(.visible)
    }

    private func itemGrid(items: [LaunchpadItem], layout: AppGridLayout) -> some View {
        let gridColumns = Array(
            repeating: GridItem(.fixed(layout.cellWidth), spacing: layout.columnSpacing),
            count: layout.columnCount
        )

        return LazyVGrid(columns: gridColumns, spacing: layout.rowSpacing) {
            ForEach(items) { item in
                itemView(item: item)
            }
        }
        .frame(width: layout.contentWidth)
    }

    @ViewBuilder
    private func itemView(item: LaunchpadItem) -> some View {
        switch item {
        case .app(let app):
            AppIconView(
                app: app,
                icon: vm.icon(for: app.bundleID),
                iconSize: config.iconSize,
                showLabel: config.iconLabelVisible,
                isEditMode: vm.isEditMode,
                onTap: {
                    if vm.isEditMode { return }
                    if let onLaunch {
                        onLaunch(app)
                    } else {
                        vm.launch(app)
                    }
                }
            )

        case .folder(let folder):
            FolderView(
                folder: folder,
                iconSize: config.iconSize,
                showLabel: config.iconLabelVisible,
                isEditMode: vm.isEditMode,
                iconProvider: { vm.icon(for: $0) },
                onOpen: { vm.toggleFolder(folder.id) }
            )
        }
    }

    private var currentPageIndex: Int {
        min(max(vm.currentPage, 0), max(vm.pages.count - 1, 0))
    }

    private var currentPageItems: [LaunchpadItem] {
        guard !vm.pages.isEmpty else { return [] }
        return vm.pages[currentPageIndex]
    }

    private var pageSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 80)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < -80 {
                    vm.showNextPage()
                } else if value.translation.width > 80 {
                    vm.showPreviousPage()
                }
            }
    }
}
