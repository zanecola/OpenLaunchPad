import SwiftUI

enum AppGridMode {
    case paged
    case scrolling

    func requestedColumns(configuredColumns: Int) -> Int {
        switch self {
        case .paged: configuredColumns
        case .scrolling: 0
        }
    }
}

struct AppGridLayout {
    let columnCount: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat
    let contentWidth: CGFloat
    let viewportHeight: CGFloat

    init(size: CGSize, iconSize: CGFloat, requestedColumns: Int, showsLabels: Bool = true) {
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
        self.cellHeight = LaunchpadIconMetrics.cellHeight(for: iconSize, showsLabel: showsLabels)
        self.columnSpacing = columnSpacing
        self.rowSpacing = min(max(size.height * 0.04, 24), 48)
        self.contentWidth = CGFloat(columnCount) * cellWidth + CGFloat(max(columnCount - 1, 0)) * columnSpacing
        self.viewportHeight = size.height
    }

    func contentHeight(itemCount: Int) -> CGFloat {
        guard itemCount > 0 else { return 0 }
        let rowCount = Int(ceil(Double(itemCount) / Double(columnCount)))
        return CGFloat(rowCount) * cellHeight + CGFloat(max(rowCount - 1, 0)) * rowSpacing
    }
}

/// Paginated grid of app icons and folders.
struct AppGridView: View {
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(ConfigStore.self) private var config
    let mode: AppGridMode
    private let onLaunch: ((AppItem) -> Void)?
    @State private var itemFrames: [UUID: CGRect] = [:]
    @State private var activeTarget: DragHoverTarget?

    init(
        mode: AppGridMode = .paged,
        onLaunch: ((AppItem) -> Void)? = nil
    ) {
        self.mode = mode
        self.onLaunch = onLaunch
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = AppGridLayout(
                size: proxy.size,
                iconSize: config.iconSize,
                requestedColumns: mode.requestedColumns(configuredColumns: config.gridColumns),
                showsLabels: config.iconLabelVisible
            )

            ZStack {
                Color.clear
                    .contentShape(Rectangle())

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
                .padding(.top, 24)
                .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .launchpadScrollAppearance()
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, Color(nsColor: .windowBackgroundColor).opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 38)
            .allowsHitTesting(false)
        }
    }

    private func itemGrid(items: [LaunchpadItem], layout: AppGridLayout) -> some View {
        let gridColumns = Array(
            repeating: GridItem(
                .fixed(layout.cellWidth),
                spacing: layout.columnSpacing,
                alignment: .top
            ),
            count: layout.columnCount
        )

        return LazyVGrid(columns: gridColumns, spacing: layout.rowSpacing) {
            ForEach(items) { item in
                itemView(item: item)
                    .frame(
                        width: layout.cellWidth,
                        height: layout.cellHeight,
                        alignment: .top
                    )
                    .contentShape(Rectangle())
                    .overlay(alignment: activeTarget?.alignment(for: item.id) ?? .center) {
                        dragTargetIndicator(for: item.id, width: layout.cellWidth)
                    }
                    .launchpadItemFrame(id: item.id)
            }

        }
        .frame(width: layout.contentWidth)
        .onPreferenceChange(LaunchpadItemFramePreferenceKey.self) { frames in
            itemFrames = frames
        }
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
                dragPayload: LaunchpadDragPayload(itemID: app.id, kind: .app),
                onDragChanged: handleDragChanged,
                onDragEnded: handleDragEnded,
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
                dragPayload: LaunchpadDragPayload(itemID: folder.id, kind: .folder),
                onDragChanged: handleDragChanged,
                onDragEnded: handleDragEnded,
                onOpen: { vm.toggleFolder(folder.id) }
            )
        }
    }

    @ViewBuilder
    private func dragTargetIndicator(for itemID: UUID, width: CGFloat) -> some View {
        if activeTarget?.itemID == itemID {
            switch activeTarget?.zone {
            case .leading, .trailing:
                Capsule()
                    .fill(.white.opacity(0.82))
                    .frame(width: 4, height: width * 0.78)
            case .center:
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.58), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.white.opacity(0.08))
                    )
                    .frame(width: width, height: width)
            case nil:
                EmptyView()
            }
        }
    }

    private func handleDragChanged(payload: LaunchpadDragPayload, location: CGPoint) {
        activeTarget = hoverTarget(for: payload, at: location)
    }

    private func handleDragEnded(payload: LaunchpadDragPayload, location: CGPoint) {
        defer { activeTarget = nil }
        guard let hoverTarget = hoverTarget(for: payload, at: location),
              let target = currentVisibleItems.first(where: { $0.id == hoverTarget.itemID }) else {
            return
        }
        _ = handleDrop(payload: payload, target: target, zone: hoverTarget.zone)
    }

    private func hoverTarget(for payload: LaunchpadDragPayload, at location: CGPoint) -> DragHoverTarget? {
        guard let target = currentVisibleItems.first(where: { item in
            item.id != payload.itemID && itemFrames[item.id]?.contains(location) == true
        }), let frame = itemFrames[target.id] else {
            return nil
        }
        return DragHoverTarget(
            itemID: target.id,
            zone: DropZone.classify(x: location.x - frame.minX, width: frame.width)
        )
    }

    private func handleDrop(
        payload: LaunchpadDragPayload,
        target: LaunchpadItem,
        zone: DropZone
    ) -> Bool {
        let targetKind: LaunchpadDragKind = switch target {
        case .app: .app
        case .folder: .folder
        }

        switch LaunchpadDropIntent.resolve(source: payload.kind, target: targetKind, zone: zone) {
        case .reorder(let placement):
            return vm.reorderTopLevel(itemID: payload.itemID, relativeTo: target.id, placement: placement)
        case .combineApps:
            return vm.combineApps(draggedID: payload.itemID, targetID: target.id)
        case .addToFolder:
            return vm.addApp(payload.itemID, toFolder: target.id)
        }
    }

    private var currentPageIndex: Int {
        min(max(vm.currentPage, 0), max(vm.pages.count - 1, 0))
    }

    private var currentPageItems: [LaunchpadItem] {
        guard !vm.pages.isEmpty else { return [] }
        return vm.pages[currentPageIndex]
    }

    private var currentVisibleItems: [LaunchpadItem] {
        switch mode {
        case .paged:
            return currentPageItems
        case .scrolling:
            return vm.pages.flatMap { $0 }
        }
    }

}

private struct DragHoverTarget: Equatable {
    let itemID: UUID
    let zone: DropZone

    func alignment(for id: UUID) -> Alignment {
        guard itemID == id else { return .center }
        switch zone {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}
