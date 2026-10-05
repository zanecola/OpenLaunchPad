import SwiftUI

/// Fits the full-screen page between the search bar and the page dots, inside insets that keep it
/// clear of the menu bar and the Dock. Icons shrink, down to 48 pt, until the largest page fits, so
/// every page shares one geometry. Page capacity is not limited yet (ROADMAP P1-1), so a page with
/// more rows than fit at 48 pt still overflows.
struct FullScreenPageLayout {
    static let minimumIconSize: CGFloat = 48
    static let searchTopPadding: CGFloat = 20
    static let searchBarHeight: CGFloat = 40
    static let searchBottomPadding: CGFloat = 12
    static let pageIndicatorHeight: CGFloat = 36
    static let bottomPadding: CGFloat = 12
    static let settingsButtonInset: CGFloat = 24

    let grid: AppGridLayout
    /// Height left for the grid below the search bar and, when shown, the Frequently Used row.
    let gridHeight: CGFloat
    /// False when the grid would not fit beside the row even with the smallest icons.
    let showsFrequentlyUsed: Bool

    init(
        size: CGSize,
        insets: EdgeInsets,
        iconSize: CGFloat,
        requestedColumns: Int,
        showsLabels: Bool,
        largestPageItemCount: Int,
        showsPageIndicator: Bool,
        wantsFrequentlyUsed: Bool
    ) {
        let width = max(size.width - insets.leading - insets.trailing, 0)
        let chromeHeight = insets.top + Self.searchTopPadding + Self.searchBarHeight + Self.searchBottomPadding
            + (showsPageIndicator ? Self.pageIndicatorHeight : 0) + Self.bottomPadding + insets.bottom
        let available = CGSize(width: width, height: max(size.height - chromeHeight, 0))
        let fit = { (showsFrequentlyUsed: Bool) in
            Self.fitting(
                in: available,
                iconSize: iconSize,
                requestedColumns: requestedColumns,
                showsLabels: showsLabels,
                itemCount: largestPageItemCount,
                showsFrequentlyUsed: showsFrequentlyUsed
            )
        }

        // The row stays if the grid fits beside it; otherwise the grid gets its space.
        self = (wantsFrequentlyUsed ? fit(true) : nil) ?? fit(false) ?? FullScreenPageLayout(
            grid: AppGridLayout(
                size: available,
                iconSize: min(iconSize, Self.minimumIconSize),
                requestedColumns: requestedColumns,
                showsLabels: showsLabels
            ),
            gridHeight: available.height,
            showsFrequentlyUsed: false
        )
    }

    private init(grid: AppGridLayout, gridHeight: CGFloat, showsFrequentlyUsed: Bool) {
        self.grid = grid
        self.gridHeight = gridHeight
        self.showsFrequentlyUsed = showsFrequentlyUsed
    }

    /// About a quarter of the content width, within 320-480 pt.
    static func searchFieldWidth(contentWidth: CGFloat) -> CGFloat {
        min(max(contentWidth * 0.24, 320), 480)
    }

    /// The layout with the largest icons, from `iconSize` down to the minimum, whose rows fit below
    /// the Frequently Used row, which shrinks with the grid.
    private static func fitting(
        in available: CGSize,
        iconSize: CGFloat,
        requestedColumns: Int,
        showsLabels: Bool,
        itemCount: Int,
        showsFrequentlyUsed: Bool
    ) -> FullScreenPageLayout? {
        var candidate = iconSize
        while candidate >= minimumIconSize {
            let rowHeight = showsFrequentlyUsed
                ? FrequentlyUsedAppsLayout.rowHeight(
                    configuredIconSize: candidate,
                    showsLabels: showsLabels,
                    presentation: .fullScreen
                )
                : 0
            let gridHeight = max(available.height - rowHeight, 0)
            let grid = AppGridLayout(
                size: CGSize(width: available.width, height: gridHeight),
                iconSize: candidate,
                requestedColumns: requestedColumns,
                showsLabels: showsLabels
            )
            if grid.contentHeight(itemCount: itemCount) <= gridHeight {
                return FullScreenPageLayout(grid: grid, gridHeight: gridHeight, showsFrequentlyUsed: showsFrequentlyUsed)
            }
            candidate = candidate.rounded(.up) - 1
        }
        return nil
    }
}

/// Full-screen Launchpad overlay — blur backdrop, search, grid, page dots.
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
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                        // The end of a drag or a slipped press is not a click.
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

                    if searchResults == nil && pageLayout.showsFrequentlyUsed {
                        FrequentlyUsedAppsView(
                            presentation: .fullScreen,
                            iconSize: pageLayout.grid.iconSize,
                            onLaunch: launch
                        )
                    }

                    // Content: search results or paginated grid
                    if let results = searchResults {
                        searchResultsView(results)
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
                    .animation(.spring(duration: config.animationDuration(0.3)), value: folder.id)
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
            iconSize: config.iconSize,
            requestedColumns: config.gridColumns,
            showsLabels: config.iconLabelVisible,
            largestPageItemCount: vm.pages.map(\.count).max() ?? 0,
            showsPageIndicator: vm.pages.count > 1,
            wantsFrequentlyUsed: config.showFrequentlyUsedApps && !vm.frequentlyUsedApps(limit: 1).isEmpty
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
    /// caret while there is text to edit: a search query, or an open folder's name.
    private var arrowKeysTurnPages: Bool {
        vm.searchQuery.isEmpty && vm.expandedFolderID == nil
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

    @ViewBuilder
    private func searchResultsView(_ results: [LaunchpadItem]) -> some View {
        if results.isEmpty {
            // The full-screen backdrop is dark in either appearance.
            ContentUnavailableView.search(text: vm.searchQuery)
                .environment(\.colorScheme, .dark)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let cols = Array(repeating: GridItem(.fixed(config.iconSize + 24), spacing: 12), count: 7)
            ScrollView {
                LazyVGrid(columns: cols, spacing: 16) {
                    ForEach(results) { item in
                        switch item {
                        case .app(let app):
                            AppIconView(
                                app: app,
                                icon: vm.icon(for: app.bundleID),
                                iconSize: config.iconSize,
                                showLabel: config.iconLabelVisible,
                                isEditMode: false,
                                onTap: { launch(app) }
                            )
                        case .folder(let folder):
                            FolderView(
                                folder: folder,
                                iconSize: config.iconSize,
                                showLabel: config.iconLabelVisible,
                                isEditMode: false,
                                iconProvider: { vm.icon(for: $0) },
                                onOpen: { vm.toggleFolder(folder.id) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .launchpadScrollAppearance()
        }
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var backdrop: some View {
        LaunchpadBackdropView(mode: .fullScreen, dim: config.backgroundDim)
            .ignoresSafeArea()
    }
}
