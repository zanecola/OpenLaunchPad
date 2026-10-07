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
    let iconSize: CGFloat
    let columnCount: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat
    let contentWidth: CGFloat
    /// Where a tile sits in its cell.
    let tileAlignment: Alignment

    /// The width a tile takes when tiles are packed: its icon with 20 pt either side.
    static func tileWidth(for iconSize: CGFloat) -> CGFloat {
        iconSize + 40
    }

    /// Packed tiles in as many columns as fit, up to `requestedColumns` (0 for no limit).
    init(size: CGSize, iconSize: CGFloat, requestedColumns: Int, showsLabels: Bool = true) {
        let horizontalPadding = min(max(size.width * 0.06, 24), 120)
        let availableWidth = max(size.width - horizontalPadding * 2, iconSize)
        let cellWidth = Self.tileWidth(for: iconSize)
        let minimumSpacing: CGFloat = 24
        let fittingColumns = max(1, Int((availableWidth + minimumSpacing) / (cellWidth + minimumSpacing)))
        let preferredColumns = requestedColumns > 0 ? requestedColumns : fittingColumns
        let columnCount = min(preferredColumns, fittingColumns)
        let naturalSpacing = columnCount > 1
            ? (availableWidth - CGFloat(columnCount) * cellWidth) / CGFloat(columnCount - 1)
            : 0
        let columnSpacing = columnCount > 1 ? min(max(naturalSpacing, minimumSpacing), 96) : 0

        self.iconSize = iconSize
        self.columnCount = columnCount
        self.cellWidth = cellWidth
        self.cellHeight = LaunchpadIconMetrics.cellHeight(for: iconSize, showsLabel: showsLabels)
        self.columnSpacing = columnSpacing
        self.rowSpacing = min(max(size.height * 0.04, 24), 48)
        self.contentWidth = CGFloat(columnCount) * cellWidth + CGFloat(max(columnCount - 1, 0)) * columnSpacing
        tileAlignment = .top
    }

    /// Full screen's fixed slots: `columns` × `rows` cells that fill `size` inside side margins
    /// of max(48, 9%) of its width. Tiles are centered in them, so the spare height is shared
    /// above and below each row, and a slot is at the same place on every page.
    init(slotsIn size: CGSize, columns: Int, rows: Int, iconSize: CGFloat) {
        let margin = max(48, size.width * 0.09)
        let cellWidth = max(size.width - margin * 2, 0) / CGFloat(columns)

        self.iconSize = iconSize
        columnCount = columns
        self.cellWidth = cellWidth
        cellHeight = size.height / CGFloat(rows)
        columnSpacing = 0
        rowSpacing = 0
        contentWidth = cellWidth * CGFloat(columns)
        tileAlignment = .center
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
    /// Geometry fitted by the full-screen page; without it the grid sizes itself to its frame.
    private let fittedLayout: AppGridLayout?
    private let onLaunch: ((AppItem) -> Void)?
    /// A click on empty space on a page, which the page's scroll view would otherwise take.
    private let onEmptySpaceClick: () -> Void
    @State private var itemFrames: [UUID: CGRect] = [:]
    @State private var activeTarget: DragHoverTarget?

    init(
        mode: AppGridMode = .paged,
        layout: AppGridLayout? = nil,
        onLaunch: ((AppItem) -> Void)? = nil,
        onEmptySpaceClick: @escaping () -> Void = {}
    ) {
        self.mode = mode
        self.fittedLayout = layout
        self.onLaunch = onLaunch
        self.onEmptySpaceClick = onEmptySpaceClick
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = fittedLayout ?? AppGridLayout(
                size: proxy.size,
                iconSize: config.popupIconSize,
                requestedColumns: mode.requestedColumns(configuredColumns: config.gridColumns),
                showsLabels: config.iconLabelVisible
            )

            ZStack {
                // Not hit-testable, so clicks between icons reach the launcher's backdrop.
                Color.clear

                if vm.isLoading {
                    ProgressView()
                } else if let error = vm.loadError {
                    Text(error)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else if vm.pages.isEmpty {
                    Text("No applications found")
                        .foregroundStyle(.secondary)
                } else {
                    switch mode {
                    case .paged:
                        pagedGrid(layout: layout, pageSize: proxy.size)
                    case .scrolling:
                        scrollingGrid(layout: layout)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // A drag cut short by the launcher closing never drops, so its indicator ends with the show.
        .onLauncherShow {
            if activeTarget != nil { activeTarget = nil }
        }
    }

    /// Pages side by side in a scroll view, which follows the fingers with momentum and rubber
    /// banding. The mouse wheel, arrow keys and dots scroll it to the current page.
    private func pagedGrid(layout: AppGridLayout, pageSize: CGSize) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(vm.pages.indices, id: \.self) { index in
                    // Top-anchored, so a partly filled page keeps its rows where the other pages have them.
                    itemGrid(items: vm.pages[index], layout: layout)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .background { EmptySpaceClickTarget(action: onEmptySpaceClick) }
                        // Not containerRelativeFrame: after a resize, the lazy stack kept the
                        // pages it wasn't showing at their old width.
                        .frame(width: pageSize.width, height: pageSize.height)
                        .modifier(OffPageAccessibility(index: index))
                }
            }
            .scrollTargetLayout()
            // Collected here: on each page, every page would replace the others' frames.
            .onPreferenceChange(LaunchpadItemFramePreferenceKey.self) { frames in
                itemFrames = frames
            }
        }
        // Aligned to the page-wide views, not .paging, which offers no limit, so a flick turns one page.
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        .scrollIndicators(.never)
        // Turning the page clears the drop indicator on the old page.
        .modifier(FollowsCurrentPage(onTurn: { activeTarget = nil }))
        .background {
            PageWheelMonitor(
                // The open folder scrolls with the wheel itself.
                isEnabled: { [vm] in vm.expandedFolderID == nil },
                onPrevious: vm.showPreviousPage,
                onNext: vm.showNextPage
            )
            .frame(width: 0, height: 0)
        }
    }

    private func scrollingGrid(layout: AppGridLayout) -> some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                FrequentlyUsedSection(layout: layout, onLaunch: launch)
                itemGrid(items: vm.pages.flatMap { $0 }, layout: layout)
                    .onPreferenceChange(LaunchpadItemFramePreferenceKey.self) { frames in
                        itemFrames = frames
                    }
            }
            .padding(.top, 24)
            .padding(.bottom, 34)
        }
        .modifier(ScrollsToTopOnShow())
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
                itemView(item: item, iconSize: layout.iconSize)
                    .frame(
                        width: layout.cellWidth,
                        height: layout.cellHeight,
                        alignment: layout.tileAlignment
                    )
                    .overlay(alignment: activeTarget?.alignment(for: item.id) ?? .center) {
                        dragTargetIndicator(for: item.id, width: AppGridLayout.tileWidth(for: layout.iconSize))
                    }
                    .launchpadItemFrame(id: item.id)
            }

        }
        .frame(width: layout.contentWidth)
    }

    @ViewBuilder
    private func itemView(item: LaunchpadItem, iconSize: CGFloat) -> some View {
        switch item {
        case .app(let app):
            AppIconView(
                app: app,
                icon: vm.icon(for: app.bundleID),
                iconSize: iconSize,
                showLabel: config.iconLabelVisible,
                isEditMode: vm.isEditMode,
                dragPayload: LaunchpadDragPayload(itemID: app.id, kind: .app),
                onDragChanged: handleDragChanged,
                onDragEnded: handleDragEnded,
                onTap: {
                    if vm.isEditMode { return }
                    launch(app)
                }
            )

        case .folder(let folder):
            FolderView(
                folder: folder,
                iconSize: iconSize,
                showLabel: config.iconLabelVisible,
                isEditMode: vm.isEditMode,
                iconProvider: { vm.icon(for: $0) },
                dragPayload: LaunchpadDragPayload(itemID: folder.id, kind: .folder),
                onDragChanged: handleDragChanged,
                onDragEnded: handleDragEnded,
                onOpen: { vm.toggleFolder(folder.id, from: $0) }
            )
        }
    }

    private func launch(_ app: AppItem) {
        if let onLaunch {
            onLaunch(app)
        } else {
            vm.launch(app)
        }
    }

    @ViewBuilder
    private func dragTargetIndicator(for itemID: UUID, width: CGFloat) -> some View {
        if activeTarget?.itemID == itemID {
            switch activeTarget?.zone {
            case .leading, .trailing:
                Capsule()
                    .fill(Color.primary.opacity(0.82))
                    .frame(width: 4, height: width * 0.78)
            case .center:
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.58), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
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

/// Keeps full screen's page scroll and the current page in step. The arrow keys, the dots and the
/// wheel change the page, and the scroll follows on the page-turn spring; a swipe that comes to
/// rest makes its page current. A modifier of its own, so a page turn doesn't re-render the grid.
private struct FollowsCurrentPage: ViewModifier {
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(\.launchpadMotion) private var motion
    let onTurn: () -> Void
    @State private var position = ScrollPosition(idType: Int.self)
    @State private var settling = PageScrollSettling()

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: Double.self) { geometry in
                geometry.contentOffset.x / max(geometry.containerSize.width, 1)
            } action: { _, pagePosition in
                vm.pagePosition = pagePosition
            }
            // A resize keeps the offset, which then falls on another page.
            .onScrollGeometryChange(for: CGFloat.self) { $0.containerSize.width } action: { _, _ in
                position.scrollTo(id: currentPage)
            }
            .onScrollPhaseChange { _, phase in
                if settling.phaseChanged(to: phase) {
                    vm.settlePageScroll()
                }
            }
            // Rebuilt after a search, so it starts on the page that was showing.
            .onAppear { position.scrollTo(id: currentPage) }
            .onChange(of: vm.currentPage) {
                onTurn()
                // A swipe that settled is already there.
                guard vm.pagePosition != Double(currentPage) else { return }
                withAnimation(motion.pageTurn) {
                    position.scrollTo(id: currentPage)
                }
            }
    }

    private var currentPage: Int {
        min(max(vm.currentPage, 0), max(vm.pages.count - 1, 0))
    }
}

/// VoiceOver reads only the current page, as before the pages were side by side, and the page
/// control turns them. Without this it could focus a tile on a page kept built off screen and
/// scroll there without making it current. A modifier of its own, so a page turn redraws no tiles.
private struct OffPageAccessibility: ViewModifier {
    @Environment(LaunchpadViewModel.self) private var vm
    let index: Int

    func body(content: Content) -> some View {
        content.accessibilityHidden(index != vm.currentPage)
    }
}

/// The popup stays alive between shows, so each show starts back at the top. Only this modifier
/// reads presentationID, so a show doesn't re-render the grid.
private struct ScrollsToTopOnShow: ViewModifier {
    @Environment(LaunchpadViewModel.self) private var vm
    @State private var position = ScrollPosition(edge: .top)

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onChange(of: vm.presentationID) { position.scrollTo(edge: .top) }
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
