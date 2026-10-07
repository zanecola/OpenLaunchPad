import SwiftUI
import AppKit

struct FolderView: View {
    let folder: FolderItem
    let iconSize: Double
    let showLabel: Bool
    let isEditMode: Bool
    let iconProvider: (String) -> NSImage
    var dragPayload: LaunchpadDragPayload?
    var onDragChanged: (LaunchpadDragPayload, CGPoint) -> Void = { _, _ in }
    var onDragEnded: (LaunchpadDragPayload, CGPoint) -> Void = { _, _ in }
    /// Gets the tile's frame in its window, which the open folder grows out of.
    var onOpen: (_ tileFrame: CGRect?) -> Void = { _ in }
    var onLaunch: (AppItem) -> Void = { _ in }

    @State private var tileFrame = TileFrame()
    @Environment(LaunchpadDragState.self) private var dragState
    /// Also tells which backdrop the tile sits on: the dark full screen or the adaptive popup.
    @Environment(\.launchpadLabelStyle) private var labelStyle

    var body: some View {
        content
            .opacity(dragState.active?.payload.itemID == folder.id ? 0.35 : 1)
            .launchpadGestureDrag(
                payload: dragPayload,
                item: .folder(folder),
                onDragChanged: onDragChanged,
                onDragEnded: onDragEnded
            )
            .launchpadTile { onOpen(tileFrame.rect) }
    }

    private var content: some View {
        VStack(spacing: 6) {
            folderIcon

            if showLabel {
                LaunchpadIconLabel(title: folder.title, iconSize: CGFloat(iconSize))
            }
        }
        .contentShape(Rectangle())
        .help(folder.title)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(folder.title)
        .accessibilityValue(folder.apps.count == 1 ? "1 app" : "\(folder.apps.count) apps")
        .accessibilityHint("Opens folder")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) { onOpen(tileFrame.rect) }
    }

    /// A 3×3 preview in an iconSize slot. The tile is the visible body of a macOS app icon in that
    /// slot, so it matches the apps beside it and its label sits on their baseline.
    private var folderIcon: some View {
        let slot = CGFloat(iconSize)
        let tile = slot * LaunchpadIconMetrics.bodyScale
        let cellSize = tile * 0.29
        let shape = RoundedRectangle(cornerRadius: tile * 0.225, style: .continuous)
        let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: 0), count: 3)
        let previewIcons = folder.apps.prefix(9).map { iconProvider($0.bundleID) }

        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<9, id: \.self) { i in
                if i < previewIcons.count {
                    Image(nsImage: previewIcons[i])
                        .resizable()
                        .frame(width: cellSize, height: cellSize)
                } else {
                    Color.clear.frame(width: cellSize, height: cellSize)
                }
            }
        }
        .padding(tile * 0.065)
        .frame(width: tile, height: tile)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { tileFrame.rect = $0 }
        .background { tileFill(shape) }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .frame(width: slot, height: slot)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func tileFill(_ shape: RoundedRectangle) -> some View {
        switch labelStyle {
        case .onDarkBackdrop:
            Color.clear
                .glassEffect(.regular.tint(.white.opacity(0.08)), in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
        case .adaptive:
            shape
                .fill(.quaternary)
                .overlay(shape.strokeBorder(.separator, lineWidth: 0.5))
        }
    }
}

/// Where a tile is, kept outside SwiftUI's view state, so following the tile as the pages scroll
/// doesn't re-render it.
private final class TileFrame {
    var rect: CGRect?
}

/// Sizes an open folder to its apps: three to five columns, fewer when the space is narrower, and
/// up to three rows. More apps go on further pages in full screen, with a page control below them,
/// and scroll in the popup. The folder's name sits above the panel.
struct FolderPanelLayout {
    static let minimumColumns = 3
    static let maximumColumns = 5
    static let maximumVisibleRows = 3
    static let columnSpacing: CGFloat = 24
    static let rowSpacing: CGFloat = 20
    static let horizontalPadding: CGFloat = 32
    static let verticalPadding: CGFloat = 28
    static let titleSpacing: CGFloat = 20
    /// Inside the panel, below the apps, when full screen has more than one page.
    static let pageIndicatorHeight: CGFloat = 24

    let iconSize: CGFloat
    let columnCount: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let gridWidth: CGFloat
    /// The grid's viewport: one page in full screen; in the popup, more rows scroll.
    let gridHeight: CGFloat
    /// The name's row above the panel.
    let titleHeight: CGFloat
    /// How many apps a full-screen page holds; nil in the popup, which scrolls instead.
    let pageCapacity: Int?
    let pageCount: Int

    static func titleHeight(for backdrop: LaunchpadBackdropMode) -> CGFloat {
        backdrop == .fullScreen ? 44 : 28
    }

    /// `availableSize` is the space the panel and the name above it may take.
    init(appCount: Int, iconSize: CGFloat, showsLabels: Bool, availableSize: CGSize, backdrop: LaunchpadBackdropMode) {
        // Packed tiles, as in the popup grid (AppGridLayout).
        let cellWidth = AppGridLayout.tileWidth(for: iconSize)
        let cellHeight = LaunchpadIconMetrics.cellHeight(for: iconSize, showsLabel: showsLabels)
        let titleHeight = Self.titleHeight(for: backdrop)
        let gridSpace = CGSize(
            width: availableSize.width - Self.horizontalPadding * 2,
            height: availableSize.height - Self.verticalPadding * 2 - titleHeight - Self.titleSpacing
        )
        let fittingColumns = Int((gridSpace.width + Self.columnSpacing) / (cellWidth + Self.columnSpacing))
        let columnCount = max(1, min(max(appCount, Self.minimumColumns), Self.maximumColumns, fittingColumns))
        let rowCount = (max(appCount, 1) + columnCount - 1) / columnCount
        func height(rows: Int) -> CGFloat {
            CGFloat(rows) * cellHeight + CGFloat(max(rows - 1, 0)) * Self.rowSpacing
        }
        func fittingRows(in height: CGFloat) -> Int {
            min(Self.maximumVisibleRows, max(1, Int((height + Self.rowSpacing) / (cellHeight + Self.rowSpacing))))
        }

        switch backdrop {
        case .fullScreen:
            // Apps that don't fit on one page make room for the page control below them.
            let rowsPerPage = rowCount <= fittingRows(in: gridSpace.height)
                ? rowCount
                : fittingRows(in: gridSpace.height - Self.pageIndicatorHeight)
            let capacity = columnCount * rowsPerPage
            pageCapacity = capacity
            pageCount = (max(appCount, 1) + capacity - 1) / capacity
            gridHeight = height(rows: rowsPerPage)
        case .popup:
            pageCapacity = nil
            pageCount = 1
            gridHeight = max(0, min(height(rows: min(rowCount, Self.maximumVisibleRows)), gridSpace.height))
        }
        self.iconSize = iconSize
        self.columnCount = columnCount
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
        self.titleHeight = titleHeight
        gridWidth = CGFloat(columnCount) * cellWidth + CGFloat(columnCount - 1) * Self.columnSpacing
    }

    var panelSize: CGSize {
        CGSize(
            width: gridWidth + Self.horizontalPadding * 2,
            height: gridHeight + Self.verticalPadding * 2 + (pageCount > 1 ? Self.pageIndicatorHeight : 0)
        )
    }

    /// The panel and the name above it.
    var size: CGSize {
        CGSize(width: panelSize.width, height: titleHeight + Self.titleSpacing + panelSize.height)
    }

    /// Where the panel is when the folder is centered in `area`.
    func panelFrame(centeredIn area: CGRect) -> CGRect {
        CGRect(
            x: area.midX - panelSize.width / 2,
            y: area.midY - size.height / 2 + titleHeight + Self.titleSpacing,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    /// The apps on each full-screen page; in the popup, all of them on one.
    func pages<Item>(_ items: [Item]) -> [[Item]] {
        guard let pageCapacity else { return [items] }
        return stride(from: 0, to: items.count, by: pageCapacity).map {
            Array(items[$0..<min($0 + pageCapacity, items.count)])
        }
    }
}

/// How an open folder sits on its tile as it starts to grow out of it, and as it finishes
/// shrinking back: scaled about the panel's center until the panel fits in the tile, and moved
/// so the two centers meet.
struct FolderZoom: Equatable {
    var scale: CGFloat
    var offset: CGSize
    /// The panel's center, as a unit point of the space the zoom is applied in.
    var anchor: UnitPoint

    /// `tile` and `panel` are frames in `bounds`, the space the zoom is applied in. Without a
    /// tile, such as for Return on a search result, the panel grows a little in place.
    init(tile: CGRect?, panel: CGRect, in bounds: CGSize) {
        anchor = UnitPoint(x: panel.midX / max(bounds.width, 1), y: panel.midY / max(bounds.height, 1))
        guard let tile else {
            scale = 0.85
            offset = .zero
            return
        }
        let fit = min(tile.width / max(panel.width, 1), tile.height / max(panel.height, 1))
        scale = min(max(fit, 0.01), 1)
        offset = CGSize(width: tile.midX - panel.midX, height: tile.midY - panel.midY)
    }

    /// The open folder at rest.
    var settled: FolderZoom {
        var settled = self
        settled.scale = 1
        settled.offset = .zero
        return settled
    }
}

private struct FolderZoomEffect: ViewModifier {
    let zoom: FolderZoom

    func body(content: Content) -> some View {
        content
            .scaleEffect(zoom.scale, anchor: zoom.anchor)
            .offset(zoom.offset)
    }
}

extension AnyTransition {
    static func folderZoom(_ zoom: FolderZoom) -> AnyTransition {
        AnyTransition.modifier(
            active: FolderZoomEffect(zoom: zoom),
            identity: FolderZoomEffect(zoom: zoom.settled)
        )
        .combined(with: .opacity)
    }
}

extension View {
    /// Blurs a launcher surface's content while a folder is open over it.
    func blursBehindOpenFolder() -> some View {
        modifier(OpenFolderBlur())
    }
}

/// A modifier of its own, so opening a folder doesn't re-render the content it blurs.
private struct OpenFolderBlur: ViewModifier {
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(\.launchpadMotion) private var motion

    func body(content: Content) -> some View {
        let radius: CGFloat = vm.expandedFolderID == nil ? 0 : 10
        content.animation(motion.folderBackdropFade) { $0.blur(radius: radius) }
    }
}

// MARK: - Expanded folder overlay

/// The open folder over a launcher surface: it grows out of the tile it was opened from and
/// shrinks back into it, while the surface dims (and blurs, with `blursBehindOpenFolder()`).
/// A click on the dimmed surface closes it.
struct FolderOverlay: View {
    let backdrop: LaunchpadBackdropMode
    /// The launcher grid's icon size, so apps look the same inside the folder.
    let iconSize: CGFloat
    let showsLabels: Bool
    /// Keeps the folder clear of the surface's edges and search bar.
    let insets: EdgeInsets
    let dim: Double
    var onLaunch: (AppItem) -> Void = { _ in }

    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(\.launchpadMotion) private var motion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let folder = vm.expandedFolder {
                    Color.black.opacity(dim)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: vm.closeFolder)
                        .accessibilityHidden(true)
                        .transition(.opacity.animation(motion.folderBackdropFade))

                    let area = CGRect(
                        x: insets.leading,
                        y: insets.top,
                        width: max(proxy.size.width - insets.leading - insets.trailing, 0),
                        height: max(proxy.size.height - insets.top - insets.bottom, 0)
                    )
                    let layout = FolderPanelLayout(
                        appCount: folder.apps.count,
                        iconSize: iconSize,
                        showsLabels: showsLabels,
                        availableSize: area.size,
                        backdrop: backdrop
                    )
                    FolderExpandedView(
                        folder: folder,
                        layout: layout,
                        backdrop: backdrop,
                        showLabel: showsLabels,
                        iconProvider: { vm.icon(for: $0) },
                        onLaunch: onLaunch
                    )
                    .id(folder.id)
                    .position(x: area.midX, y: area.midY)
                    // SwiftUI applies a transition to the inserted view as a whole, here the
                    // positioned folder, which fills the overlay; the zoom is in its space.
                    .transition(motion.transition(.folderZoom(FolderZoom(
                        tile: tileFrame(in: proxy),
                        panel: layout.panelFrame(centeredIn: area),
                        in: proxy.size
                    ))))
                }
            }
            .animation(motion.folderZoom, value: vm.expandedFolderID)
        }
    }

    /// The tile reported its frame in the window.
    private func tileFrame(in proxy: GeometryProxy) -> CGRect? {
        let origin = proxy.frame(in: .global).origin
        return vm.expandedFolderTileFrame?.offsetBy(dx: -origin.x, dy: -origin.y)
    }
}

struct FolderExpandedView: View {
    let folder: FolderItem
    let layout: FolderPanelLayout
    /// Full screen pages through more than three rows; the popup scrolls them.
    let backdrop: LaunchpadBackdropMode
    let showLabel: Bool
    let iconProvider: (String) -> NSImage
    var onLaunch: (AppItem) -> Void = { _ in }

    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(\.launchpadMotion) private var motion
    @State private var appFrames: [UUID: CGRect] = [:]
    @State private var panelFrame: CGRect = .zero
    @State private var activeTarget: FolderDragHoverTarget?
    @State private var isDraggingOutside = false
    @State private var pagePosition = ScrollPosition(idType: Int.self)
    @State private var currentPage = 0

    private static let panelShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    var body: some View {
        VStack(spacing: FolderPanelLayout.titleSpacing) {
            FolderTitle(title: folder.title, backdrop: backdrop, width: layout.panelSize.width, height: layout.titleHeight)
            panel
        }
        .frame(width: layout.size.width, height: layout.size.height)
        // VoiceOver's escape gesture, since full screen has no close button.
        .accessibilityAction(.escape) { _ = vm.stepBack() }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            switch backdrop {
            case .fullScreen: pagedGrid
            case .popup: scrollingGrid
            }
        }
        .frame(width: layout.gridWidth)
        .padding(.horizontal, FolderPanelLayout.horizontalPadding)
        .padding(.vertical, FolderPanelLayout.verticalPadding)
        .background(.regularMaterial, in: Self.panelShape)
        .overlay {
            if isDraggingOutside {
                Self.panelShape
                    .stroke(Color.primary.opacity(0.58), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
            }
        }
        .onTapGesture {}  // absorb taps so background tap closes
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { panelFrame = proxy.frame(in: .global) }
                    .onChange(of: proxy.frame(in: .global)) { _, frame in
                        panelFrame = frame
                    }
            }
        }
        .onPreferenceChange(LaunchpadItemFramePreferenceKey.self) { frames in
            appFrames = frames
        }
    }

    /// Pages side by side, as on the launcher's own pages: a swipe follows the fingers, and the
    /// wheel and the dots turn them.
    private var pagedGrid: some View {
        let pages = layout.pages(folder.apps)
        return VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(pages.indices, id: \.self) { index in
                        appGrid(pages[index])
                            .frame(width: layout.gridWidth, height: layout.gridHeight, alignment: .top)
                            .accessibilityHidden(index != currentPage)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition($pagePosition)
            .scrollIndicators(.never)
            .onScrollGeometryChange(for: Int.self) { geometry in
                Int((geometry.contentOffset.x / max(geometry.containerSize.width, 1)).rounded())
            } action: { _, page in
                currentPage = min(max(page, 0), pages.count - 1)
            }
            .frame(height: layout.gridHeight)
            .background {
                // Also keeps the wheel from scrolling the launcher's pages behind the folder.
                PageWheelMonitor(
                    isEnabled: { true },
                    onPrevious: { showPage(currentPage - 1, of: pages.count) },
                    onNext: { showPage(currentPage + 1, of: pages.count) }
                )
                .frame(width: 0, height: 0)
            }

            if pages.count > 1 {
                FolderPageDots(pageCount: pages.count, currentPage: currentPage) {
                    showPage($0, of: pages.count)
                }
                .frame(height: FolderPanelLayout.pageIndicatorHeight)
            }
        }
    }

    private var scrollingGrid: some View {
        ScrollView(.vertical) {
            appGrid(folder.apps)
        }
        // Reaches into the panel's padding, so the hover highlight of the first and last rows
        // isn't clipped.
        .contentMargins(.vertical, TileFeedback.highlightOutset, for: .scrollContent)
        .frame(height: layout.gridHeight + TileFeedback.highlightOutset * 2)
        .padding(.vertical, -TileFeedback.highlightOutset)
        .scrollIndicators(.hidden)
        .launchpadScrollAppearance()
    }

    private func appGrid(_ apps: [AppItem]) -> some View {
        let gridColumns = Array(
            repeating: GridItem(.fixed(layout.cellWidth), spacing: FolderPanelLayout.columnSpacing, alignment: .top),
            count: layout.columnCount
        )
        return LazyVGrid(columns: gridColumns, spacing: FolderPanelLayout.rowSpacing) {
            ForEach(apps) { app in
                AppIconView(
                    app: app,
                    icon: iconProvider(app.bundleID),
                    iconSize: layout.iconSize,
                    showLabel: showLabel,
                    isEditMode: false,
                    dragPayload: LaunchpadDragPayload(itemID: app.id, kind: .app),
                    onDragChanged: handleDragChanged,
                    onDragEnded: handleDragEnded,
                    onTap: { onLaunch(app) }
                )
                .frame(width: layout.cellWidth, height: layout.cellHeight, alignment: .top)
                .overlay(alignment: activeTarget?.alignment(for: app.id) ?? .center) {
                    folderDragTargetIndicator(for: app.id)
                }
                .launchpadItemFrame(id: app.id)
            }
        }
    }

    private func showPage(_ page: Int, of pageCount: Int) {
        let page = min(max(page, 0), pageCount - 1)
        guard page != currentPage else { return }
        withAnimation(motion.pageTurn) {
            pagePosition.scrollTo(id: page)
        }
    }

    /// The apps a drop can land on: those on the page showing. Other pages' apps sit beside the
    /// panel, clipped, where a drag out of the folder ends.
    private var droppableApps: [AppItem] {
        let pages = layout.pages(folder.apps)
        return pages.indices.contains(currentPage) ? pages[currentPage] : []
    }

    @ViewBuilder
    private func folderDragTargetIndicator(for appID: UUID) -> some View {
        if activeTarget?.appID == appID {
            switch activeTarget?.zone {
            case .leading, .trailing:
                Capsule()
                    .fill(Color.primary.opacity(0.82))
                    .frame(width: 4, height: layout.iconSize * 0.62)
            case .center:
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.52), lineWidth: 2)
                    .frame(width: layout.iconSize + 20, height: layout.iconSize + 20)
            case nil:
                EmptyView()
            }
        }
    }

    private func handleDragChanged(payload: LaunchpadDragPayload, location: CGPoint) {
        guard payload.kind == .app else { return }
        activeTarget = hoverTarget(for: payload, at: location)
        isDraggingOutside = activeTarget == nil && !panelFrame.contains(location)
    }

    private func handleDragEnded(payload: LaunchpadDragPayload, location: CGPoint) {
        guard payload.kind == .app else { return }
        defer {
            activeTarget = nil
            isDraggingOutside = false
        }

        if let activeTarget,
           let targetApp = folder.apps.first(where: { $0.id == activeTarget.appID }) {
            reorder(payload, relativeTo: targetApp, zone: activeTarget.zone)
            return
        }

        if !panelFrame.contains(location) {
            vm.removeApp(payload.itemID, fromFolder: folder.id)
        }
    }

    private func reorder(_ payload: LaunchpadDragPayload, relativeTo targetApp: AppItem, zone: DropZone) {
        guard payload.itemID != targetApp.id else { return }
        let placement: ItemPlacement = switch zone {
        case .leading: .before
        case .center, .trailing: .after
        }
        vm.reorderApp(payload.itemID, inFolder: folder.id, relativeTo: targetApp.id, placement: placement)
    }

    private func hoverTarget(for payload: LaunchpadDragPayload, at location: CGPoint) -> FolderDragHoverTarget? {
        guard panelFrame.contains(location),
              let targetApp = droppableApps.first(where: { app in
                  app.id != payload.itemID && appFrames[app.id]?.contains(location) == true
              }),
              let frame = appFrames[targetApp.id] else {
            return nil
        }
        return FolderDragHoverTarget(
            appID: targetApp.id,
            zone: DropZone.classify(x: location.x - frame.minX, width: frame.width)
        )
    }
}

/// The open folder's name, centered above its panel. Clicking it edits the name in place, with
/// the text selected: Return saves it, Escape cancels (`stepBack()`), and closing the folder
/// saves it. Reading the draft here keeps typing from re-rendering the folder's apps.
private struct FolderTitle: View {
    let title: String
    let backdrop: LaunchpadBackdropMode
    let width: CGFloat
    let height: CGFloat

    @Environment(LaunchpadViewModel.self) private var vm
    @FocusState private var isEditing: Bool

    private static let closeButtonDiameter: CGFloat = 22

    var body: some View {
        Group {
            if vm.folderTitleDraft != nil {
                TextField("Folder Name", text: Binding(
                    get: { vm.folderTitleDraft ?? "" },
                    // A field that is going away may write its text back; that must not reopen it.
                    set: { if vm.folderTitleDraft != nil { vm.folderTitleDraft = $0 } }
                ))
                .textFieldStyle(.plain)
                .font(titleFont)
                .multilineTextAlignment(.center)
                .focused($isEditing)
                .onSubmit(vm.commitFolderRename)
                // Focusing the field as it appears is too early in full screen, which then keeps
                // focus on Search; a turn of the run loop later it selects the name.
                .onAppear { DispatchQueue.main.async { isEditing = true } }
                .padding(.horizontal, 16)
                .frame(width: min(width - titleInset * 2, 420), height: height)
                .background { LaunchpadFieldBackground(backdrop: backdrop) }
            } else {
                Button(action: vm.beginRenamingFolder) {
                    styledTitle
                        .lineLimit(1)
                        .padding(.horizontal, titleInset)
                }
                .buttonStyle(.plain)
                .help("Rename Folder")
                .accessibilityLabel(title)
                .accessibilityHint("Renames the folder")
            }
        }
        .frame(width: width, height: height)
        .overlay(alignment: .trailing) {
            if backdrop == .popup { closeButton }
        }
        // Focus leaving the field, without Return or Escape, saves the name too.
        .onChange(of: isEditing) { wasEditing, isEditing in
            if wasEditing && !isEditing { vm.commitFolderRename() }
        }
    }

    private var titleFont: Font {
        switch backdrop {
        case .fullScreen: .system(size: 28, weight: .bold)
        case .popup: .system(size: 15, weight: .semibold)
        }
    }

    @ViewBuilder
    private var styledTitle: some View {
        switch backdrop {
        case .fullScreen:
            Text(title)
                .font(titleFont)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
        case .popup:
            Text(title)
                .font(titleFont)
                .foregroundStyle(.primary)
        }
    }

    /// Keeps the name centered and clear of the popup's close button.
    private var titleInset: CGFloat {
        backdrop == .popup ? Self.closeButtonDiameter + 8 : 0
    }

    /// Only the popup has one; full screen closes on Escape or a click outside, as Launchpad did.
    private var closeButton: some View {
        Button(action: vm.closeFolder) {
            // Glass would draw the symbol white, which vanishes on the light popup, so it matches
            // the popup's settings button instead.
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: Self.closeButtonDiameter, height: Self.closeButtonDiameter)
                .background {
                    Circle()
                        .fill(.quaternary)
                        .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Close Folder")
        .accessibilityLabel("Close Folder")
    }
}

/// The open folder's pages, as bare dots below its apps, like the launcher's own page control.
private struct FolderPageDots: View {
    let pageCount: Int
    let currentPage: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<pageCount, id: \.self) { index in
                Button {
                    onSelect(index)
                } label: {
                    PageIndicatorView.dot
                        .opacity(index == currentPage ? 1 : 0.35)
                        .frame(width: PageIndicatorView.dotBoxSize.width, height: PageIndicatorView.dotBoxSize.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Folder Page")
        .accessibilityValue("\(currentPage + 1) of \(pageCount)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onSelect(currentPage + 1)
            case .decrement: onSelect(currentPage - 1)
            @unknown default: break
            }
        }
    }
}

private struct FolderDragHoverTarget: Equatable {
    let appID: UUID
    let zone: DropZone

    func alignment(for id: UUID) -> Alignment {
        guard appID == id else { return .center }
        switch zone {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}
