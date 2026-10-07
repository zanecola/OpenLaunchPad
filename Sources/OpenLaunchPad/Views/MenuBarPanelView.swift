import SwiftUI

/// Compact Launchpad panel shown when user clicks the menu bar icon.
/// Sized by paneWidth × paneHeight from ConfigStore.
struct MenuBarPanelView: View {
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(ConfigStore.self) private var config
    @Environment(\.colorScheme) private var colorScheme
    /// Closes without launching anything.
    var onDismissRequested: () -> Void = {}
    var onAppLaunched: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    @State private var dragState = LaunchpadDragState()
    @State private var missingApp: AppItem?

    var body: some View {
        @Bindable var vm = vm
        let searchResults = vm.searchResults

        ZStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    SearchBarView(
                        text: $vm.searchQuery,
                        backdrop: .popup,
                        onSubmit: openTopSearchResult
                    )
                    SettingsButton(backdrop: .popup, action: onOpenSettings)
                }
                .padding(12)

                if let results = searchResults {
                    compactGrid(results)
                } else {
                    AppGridView(
                        mode: .scrolling,
                        onLaunch: launchAndDismiss
                    )
                }
            }
            .blursBehindOpenFolder()

            FolderOverlay(
                backdrop: .popup,
                iconSize: config.popupIconSize,
                showsLabels: config.iconLabelVisible,
                insets: Self.folderInsets,
                dim: LaunchpadBackdropView.popupFolderDim(style: config.popupBackgroundStyle, colorScheme: colorScheme),
                panelBackground: LaunchpadBackdropView.popupFolderPanel(style: config.popupBackgroundStyle),
                onLaunch: launchAndDismiss
            )

            LaunchpadDragPreviewView()
        }
        .frame(width: config.paneWidth, height: config.paneHeight)
        .background {
            PopupBackdrop()
        }
        .clipShape(LaunchpadBackdropView.popupShape)
        .overlay {
            LaunchpadBackdropView.popupShape
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
        .environment(dragState)
        .environment(\.launchpadTileHoverEffect, config.popupHoverEffect)
        .onKeyPress(.escape) {
            // Escape cancels an input method's composition rather than stepping back.
            guard !TextComposition.isActive else { return .ignored }
            if !vm.stepBack() { onDismissRequested() }
            return .handled
        }
        .missingAppAlert($missingApp) { vm.removeFromLayout($0) }
        // Both launchers stay alive between shows, so an alert or a drag the last show left
        // behind ends with it.
        .onLauncherShow {
            if missingApp != nil { missingApp = nil }
            if dragState.isDragging { dragState.end() }
        }
    }

    /// Keeps the open folder below the search header.
    private static let folderInsets = EdgeInsets(top: 64, leading: 16, bottom: 16, trailing: 16)

    @ViewBuilder
    private func compactGrid(_ results: [LaunchpadItem]) -> some View {
        if results.isEmpty {
            ContentUnavailableView.search(text: vm.searchQuery)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let cols = [GridItem(.adaptive(minimum: config.popupIconSize + 16), spacing: 8, alignment: .top)]
            ScrollView {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(results) { item in
                        switch item {
                        case .app(let app):
                            AppIconView(
                                app: app,
                                icon: vm.icon(for: app.bundleID),
                                iconSize: config.popupIconSize * 0.75,
                                showLabel: config.iconLabelVisible,
                                isEditMode: false,
                                onTap: { launchAndDismiss(app) }
                            )
                        case .folder(let folder):
                            FolderView(
                                folder: folder,
                                iconSize: config.popupIconSize * 0.75,
                                showLabel: config.iconLabelVisible,
                                isEditMode: false,
                                iconProvider: { vm.icon(for: $0) },
                                onOpen: { vm.toggleFolder(folder.id, from: $0) }
                            )
                        }
                    }
                }
                .padding(12)
            }
            .scrollIndicators(.hidden)
            .launchpadScrollAppearance()
        }
    }

    private func launchAndDismiss(_ app: AppItem) {
        guard vm.launch(app) else {
            missingApp = app
            return
        }
        // Hiding clears the search and closes the folder once the panel has faded out.
        onAppLaunched()
    }

    private func openTopSearchResult() {
        switch vm.searchResults?.first {
        case .app(let app): launchAndDismiss(app)
        case .folder(let folder): vm.openFolder(folder.id)
        case nil: break
        }
    }
}

/// The popup's background. It reads the setting, the wallpaper and the panel's place itself, so a
/// new render or a move redraws only the background.
struct PopupBackdrop: View {
    @Environment(ConfigStore.self) private var config
    @Environment(WallpaperProvider.self) private var wallpapers
    @Environment(WallpaperPlacement.self) private var placement
    @Environment(\.launchpadMotion) private var motion

    var body: some View {
        LaunchpadBackdropView(
            mode: .popup,
            style: config.popupBackgroundStyle,
            wallpaper: wallpapers.status(for: placement.screenID),
            screenSize: placement.screenSize,
            frameInScreen: placement.frameInScreen,
            wallpaperFade: motion.animation(0.18) { .easeOut(duration: $0) }
        )
        // Another screen's picture replaces this one at once rather than fading out of it.
        .id(placement.screenID)
    }
}
