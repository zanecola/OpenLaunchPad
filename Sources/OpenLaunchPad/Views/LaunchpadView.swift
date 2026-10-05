import SwiftUI

/// Fits the full-screen page between the search bar, or the Frequently Used shelf below it, and
/// the page dots, inside insets that keep it clear of the menu bar and the Dock. The page is a grid
/// of columns × rows slots that fills that space, so a partly filled page keeps its rows where the
/// other pages have them. Automatic icons are sized to the slots; a custom size draws smaller,
/// down to 48 pt, only when it does not fit.
struct FullScreenPageLayout {
    static let minimumIconSize: CGFloat = 48
    static let maximumAutomaticIconSize: CGFloat = 144
    static let searchTopPadding: CGFloat = 20
    static let searchBarHeight: CGFloat = 40
    static let searchBottomPadding: CGFloat = 12
    static let pageIndicatorHeight: CGFloat = 36
    static let bottomPadding: CGFloat = 12
    static let settingsButtonInset: CGFloat = 24

    let grid: AppGridLayout
    /// Height left for the grid below the search bar and, when shown, the Frequently Used shelf.
    let gridHeight: CGFloat
    /// nil when not wanted, or when the grid's icons would be under 48 pt beside it.
    let shelf: FrequentlyUsedShelfLayout?

    /// `customIconSize` is nil for Automatic.
    init(
        size: CGSize,
        insets: EdgeInsets,
        customIconSize: CGFloat?,
        columns: Int,
        rows: Int,
        showsLabels: Bool,
        showsPageIndicator: Bool,
        wantsFrequentlyUsed: Bool
    ) {
        let width = max(size.width - insets.leading - insets.trailing, 0)
        let chromeHeight = insets.top + Self.searchTopPadding + Self.searchBarHeight + Self.searchBottomPadding
            + (showsPageIndicator ? Self.pageIndicatorHeight : 0) + Self.bottomPadding + insets.bottom
        let available = CGSize(width: width, height: max(size.height - chromeHeight, 0))
        let fit = { (showsShelf: Bool) in
            Self.fitting(
                in: available,
                customIconSize: customIconSize,
                columns: columns,
                rows: rows,
                showsLabels: showsLabels,
                showsShelf: showsShelf
            )
        }

        // The shelf stays if the grid fits beside it; otherwise the grid gets its space.
        self = (wantsFrequentlyUsed ? fit(true) : nil) ?? fit(false) ?? FullScreenPageLayout(
            grid: AppGridLayout(slotsIn: available, columns: columns, rows: rows, iconSize: Self.minimumIconSize),
            gridHeight: available.height,
            shelf: nil
        )
    }

    private init(grid: AppGridLayout, gridHeight: CGFloat, shelf: FrequentlyUsedShelfLayout?) {
        self.grid = grid
        self.gridHeight = gridHeight
        self.shelf = shelf
    }

    /// About a quarter of the content width, within 320-480 pt.
    static func searchFieldWidth(contentWidth: CGFloat) -> CGFloat {
        min(max(contentWidth * 0.24, 320), 480)
    }

    /// The layout with the largest icons, from the custom or largest automatic size down to the
    /// minimum, that fit their slots below the Frequently Used shelf, which shrinks with the grid.
    private static func fitting(
        in available: CGSize,
        customIconSize: CGFloat?,
        columns: Int,
        rows: Int,
        showsLabels: Bool,
        showsShelf: Bool
    ) -> FullScreenPageLayout? {
        var candidate = customIconSize ?? maximumAutomaticIconSize
        while candidate >= minimumIconSize {
            let shelf = showsShelf ? FrequentlyUsedShelfLayout(gridIconSize: candidate, width: available.width) : nil
            let gridHeight = max(available.height - (shelf?.reservedHeight ?? 0), 0)
            let grid = AppGridLayout(
                slotsIn: CGSize(width: available.width, height: gridHeight),
                columns: columns,
                rows: rows,
                iconSize: candidate
            )
            if fits(grid, automatic: customIconSize == nil, showsLabels: showsLabels) {
                return FullScreenPageLayout(grid: grid, gridHeight: gridHeight, shelf: shelf)
            }
            candidate = candidate.rounded(.up) - 1
        }
        return nil
    }

    /// Automatic icons leave Launchpad's room around them: at most 62% of the slot width, and 78%
    /// of the height the label leaves. A custom size only needs 8 pt between neighboring labels
    /// (each is 16 pt wider than its icon) and between a label and the row below.
    private static func fits(_ grid: AppGridLayout, automatic: Bool, showsLabels: Bool) -> Bool {
        let icon = grid.iconSize
        let labelHeight = LaunchpadIconMetrics.contentHeight(for: icon, showsLabel: showsLabels) - icon
        if automatic {
            return icon <= 0.62 * grid.cellWidth && icon <= 0.78 * (grid.cellHeight - labelHeight)
        }
        return icon + 16 + 8 <= grid.cellWidth && icon + labelHeight + 8 <= grid.cellHeight
    }
}

/// Full-screen Launchpad overlay — backdrop, search, grid, page dots.
struct LaunchpadView: View {
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(ConfigStore.self) private var config
    /// Keeps content clear of the menu bar and the Dock; the backdrop still fills the screen.
    var contentInsets = EdgeInsets()
    /// Closes without launching anything.
    var onDismiss: () -> Void = {}
    var onAppLaunched: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    @State private var dragState = LaunchpadDragState()
    @State private var missingApp: AppItem?

    var body: some View {
        @Bindable var vm = vm
        let searchResults = vm.searchResults

        GeometryReader { proxy in
            let pageLayout = fittedPageLayout(for: proxy.size)
            ZStack {
                // Backdrop — clicks on empty space, including between icons, close the folder,
                // leave edit mode or dismiss
                emptySpaceClickTarget

                VStack(spacing: 0) {
                    // The field is centered on its own; the gear sits in the corner, clear of it.
                    SearchBarView(
                        text: $vm.searchQuery,
                        backdrop: .fullScreen,
                        onClear: vm.closeFolder,
                        onSubmit: openTopSearchResult
                    )
                        .frame(width: FullScreenPageLayout.searchFieldWidth(
                            contentWidth: proxy.size.width - contentInsets.leading - contentInsets.trailing
                        ))
                        .frame(maxWidth: .infinity)
                        .frame(height: FullScreenPageLayout.searchBarHeight)
                        .overlay(alignment: .trailing) {
                            SettingsButton(backdrop: .fullScreen, action: onOpenSettings)
                                .padding(.trailing, FullScreenPageLayout.settingsButtonInset)
                        }
                        .padding(.bottom, FullScreenPageLayout.searchBottomPadding)

                    if searchResults == nil, let shelf = pageLayout.shelf {
                        FrequentlyUsedShelf(layout: shelf, onLaunch: launch)
                            .padding(.bottom, FrequentlyUsedShelfLayout.bottomPadding)
                    }

                    // Content: search results or paginated grid
                    if let results = searchResults {
                        searchResultsView(results, grid: pageLayout.grid)
                    } else {
                        AppGridView(
                            mode: .paged,
                            layout: pageLayout.grid,
                            onLaunch: launch
                        )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Page indicator (hidden during search)
                    if searchResults == nil && vm.pages.count > 1 {
                        PageIndicatorView(pageCount: vm.pages.count, currentPage: $vm.currentPage)
                            .frame(height: FullScreenPageLayout.pageIndicatorHeight)
                    }
                }
                .padding(.top, contentInsets.top + FullScreenPageLayout.searchTopPadding)
                .padding(.bottom, contentInsets.bottom + FullScreenPageLayout.bottomPadding)
                .padding(.leading, contentInsets.leading)
                .padding(.trailing, contentInsets.trailing)

                // Folder expanded overlay
                if let folder = vm.expandedFolder {
                    // Dims the page behind the folder; a click on it closes the folder.
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { vm.closeFolder() }
                        .accessibilityHidden(true)

                    FolderExpandedView(
                        folder: folder,
                        iconSize: pageLayout.grid.iconSize,
                        showLabel: config.iconLabelVisible,
                        availableSize: CGSize(
                            width: proxy.size.width - folderInsets.leading - folderInsets.trailing,
                            height: proxy.size.height - folderInsets.top - folderInsets.bottom
                        ),
                        iconProvider: { vm.icon(for: $0) },
                        onLaunch: launch,
                        onRename: { vm.renameFolder(folder.id, to: $0) },
                        onAppDrop: { payload, targetApp, zone in
                            handleFolderAppDrop(payload: payload, targetApp: targetApp, zone: zone, folderID: folder.id)
                        },
                        onAppDraggedOut: { payload in
                            vm.removeApp(payload.itemID, fromFolder: folder.id)
                        },
                        onClose: vm.closeFolder
                    )
                    .animation(config.animationDuration(0.3).map { .spring(duration: $0) }, value: folder.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(folderInsets)
                }

                LaunchpadDragPreviewView(iconSize: pageLayout.grid.iconSize)
            }
        }
        .background(backdrop)
        .environment(dragState)
        .environment(\.launchpadLabelStyle, .onDarkBackdrop)
        .ignoresSafeArea()
        .onKeyPress(.escape) {
            // Escape cancels an input method's composition rather than stepping back.
            guard !TextComposition.isActive else { return .ignored }
            if !vm.stepBack() { onDismiss() }
            return .handled
        }
        .onKeyPress(.leftArrow) {
            guard arrowKeysTurnPages else { return .ignored }
            vm.showPreviousPage()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard arrowKeysTurnPages else { return .ignored }
            vm.showNextPage()
            return .handled
        }
        .missingAppAlert($missingApp) { vm.removeFromLayout($0) }
    }

    private func fittedPageLayout(for size: CGSize) -> FullScreenPageLayout {
        FullScreenPageLayout(
            size: size,
            insets: contentInsets,
            customIconSize: config.iconSizeMode == .custom ? config.customIconSize : nil,
            columns: config.gridColumns,
            rows: config.gridRows,
            showsLabels: config.iconLabelVisible,
            showsPageIndicator: vm.pages.count > 1,
            wantsFrequentlyUsed: config.frequentlyUsedPlacement.showsInFullScreen && !vm.frequentlyUsedApps.isEmpty
        )
    }

    /// Keeps the open folder below the search bar and inside the safe area.
    private var folderInsets: EdgeInsets {
        EdgeInsets(
            top: contentInsets.top + FullScreenPageLayout.searchTopPadding
                + FullScreenPageLayout.searchBarHeight + FullScreenPageLayout.searchBottomPadding,
            leading: contentInsets.leading + 24,
            bottom: contentInsets.bottom + FullScreenPageLayout.bottomPadding,
            trailing: contentInsets.trailing + 24
        )
    }

    /// These handlers see arrow keys before the focused text field does, so leave them to the
    /// caret while there is text to edit: a search query, an open folder's name, or text an
    /// input method is still composing.
    private var arrowKeysTurnPages: Bool {
        vm.searchQuery.isEmpty && vm.expandedFolderID == nil && !TextComposition.isActive
    }

    /// Stays open when the app can't be found, so the user can see why nothing opened.
    private func launch(_ app: AppItem) {
        if vm.launch(app) {
            onAppLaunched()
        } else {
            missingApp = app
        }
    }

    private func openTopSearchResult() {
        switch vm.searchResults?.first {
        case .app(let app): launch(app)
        case .folder(let folder): vm.expandedFolderID = folder.id
        case nil: break
        }
    }

    private func handleFolderAppDrop(
        payload: LaunchpadDragPayload,
        targetApp: AppItem,
        zone: DropZone,
        folderID: UUID
    ) -> Bool {
        guard payload.kind == .app, payload.itemID != targetApp.id else { return false }

        let placement: ItemPlacement = switch zone {
        case .leading: .before
        case .center, .trailing: .after
        }
        return vm.reorderApp(payload.itemID, inFolder: folderID, relativeTo: targetApp.id, placement: placement)
    }

    // MARK: - Search results

    /// In the grid's columns and at its icon size.
    @ViewBuilder
    private func searchResultsView(_ results: [LaunchpadItem], grid: AppGridLayout) -> some View {
        if results.isEmpty {
            // The full-screen backdrop is dark in either appearance.
            ContentUnavailableView.search(text: vm.searchQuery)
                .environment(\.colorScheme, .dark)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let cols = Array(repeating: GridItem(.fixed(grid.iconSize + 24), spacing: 12), count: grid.columnCount)
            GeometryReader { viewport in
                ScrollView {
                    LazyVGrid(columns: cols, spacing: 16) {
                        ForEach(results) { item in
                            switch item {
                            case .app(let app):
                                AppIconView(
                                    app: app,
                                    icon: vm.icon(for: app.bundleID),
                                    iconSize: grid.iconSize,
                                    showLabel: config.iconLabelVisible,
                                    isEditMode: false,
                                    onTap: { launch(app) }
                                )
                            case .folder(let folder):
                                FolderView(
                                    folder: folder,
                                    iconSize: grid.iconSize,
                                    showLabel: config.iconLabelVisible,
                                    isEditMode: false,
                                    iconProvider: { vm.icon(for: $0) },
                                    onOpen: { vm.toggleFolder(folder.id) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    // The scroll view takes clicks from the backdrop behind it, so empty space
                    // around the results catches them itself, down to the bottom of the viewport.
                    .frame(maxWidth: .infinity, minHeight: viewport.size.height, alignment: .top)
                    .background { emptySpaceClickTarget }
                }
                .scrollIndicators(.hidden)
                .launchpadScrollAppearance()
            }
        }
    }

    /// A click, not the end of a drag or a slipped press, closes the open folder, leaves edit
    /// mode or dismisses.
    private var emptySpaceClickTarget: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                guard hypot(value.translation.width, value.translation.height) < 6 else { return }
                if vm.expandedFolderID != nil {
                    vm.closeFolder()
                } else if vm.isEditMode {
                    vm.toggleEditMode()
                } else {
                    onDismiss()
                }
            })
            .accessibilityHidden(true)
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var backdrop: some View {
        FullScreenBackdrop()
            .ignoresSafeArea()
    }
}

/// Reads the background settings and the wallpaper itself, so a new render redraws only the backdrop.
private struct FullScreenBackdrop: View {
    @Environment(ConfigStore.self) private var config
    @Environment(WallpaperProvider.self) private var wallpapers

    var body: some View {
        LaunchpadBackdropView(
            mode: .fullScreen,
            style: config.backgroundStyle,
            wallpaper: wallpapers.status,
            dim: config.backgroundDim,
            wallpaperFade: config.animationDuration(0.18).map { .easeOut(duration: $0) }
        )
    }
}
