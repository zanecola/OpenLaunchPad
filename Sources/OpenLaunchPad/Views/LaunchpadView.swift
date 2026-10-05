import SwiftUI

/// Full-screen Launchpad overlay — blur backdrop, search, grid, page dots.
struct LaunchpadView: View {
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(ConfigStore.self) private var config
    /// Closes without launching anything.
    var onDismiss: () -> Void = {}
    var onAppLaunched: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    @State private var dragState = LaunchpadDragState()
    @State private var missingApp: AppItem?

    var body: some View {
        @Bindable var vm = vm
        let searchResults = vm.searchResults

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

            VStack(spacing: 0) {
                // Search bar
                SearchBarView(
                    text: $vm.searchQuery,
                    onClear: vm.closeFolder,
                    onSubmit: openTopSearchResult,
                    onOpenSettings: onOpenSettings
                )
                    .padding(.top, 40)
                    .padding(.bottom, 12)

                if searchResults == nil {
                    FrequentlyUsedAppsView(
                        presentation: .fullScreen,
                        onLaunch: launch
                    )
                }

                // Content: search results or paginated grid
                if let results = searchResults {
                    searchResultsView(results)
                } else {
                    AppGridView(
                        mode: .paged,
                        onLaunch: launch
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Page indicator (hidden during search)
                if searchResults == nil && vm.pages.count > 1 {
                    PageIndicatorView(pageCount: vm.pages.count, currentPage: $vm.currentPage)
                        .padding(.bottom, 20)
                }
            }

            // Folder expanded overlay
            if let folder = vm.expandedFolder {
                Color.black.opacity(0.001)  // captures taps to close folder
                    .ignoresSafeArea()
                    .onTapGesture { vm.closeFolder() }

                FolderExpandedView(
                    folder: folder,
                    iconSize: config.iconSize,
                    showLabel: config.iconLabelVisible,
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
            }

            LaunchpadDragPreviewView()
        }
        .background(backdrop)
        .environment(dragState)
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
        LaunchpadBackdropView(mode: .fullScreen, blurAmount: config.backgroundBlur)
            .ignoresSafeArea()
    }
}
