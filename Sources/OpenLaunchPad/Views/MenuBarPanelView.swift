import SwiftUI

/// Compact Launchpad panel shown when user clicks the menu bar icon.
/// Sized by paneWidth × paneHeight from ConfigStore.
struct MenuBarPanelView: View {
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(ConfigStore.self) private var config
    @Environment(\.dismiss) private var dismiss
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

                if searchResults == nil {
                    FrequentlyUsedAppsView(
                        presentation: .popup,
                        onLaunch: launchAndDismiss
                    )
                }

                if let results = searchResults {
                    compactGrid(results)
                } else {
                    AppGridView(
                        mode: .scrolling,
                        onLaunch: launchAndDismiss
                    )
                }
            }

            if let folder = vm.expandedFolder {
                Color.black.opacity(0.35)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: vm.closeFolder)

                FolderExpandedView(
                    folder: folder,
                    iconSize: config.iconSize,
                    showLabel: config.iconLabelVisible,
                    iconProvider: { vm.icon(for: $0) },
                    onLaunch: launchAndDismiss,
                    onRename: { vm.renameFolder(folder.id, to: $0) },
                    onAppDrop: { payload, targetApp, zone in
                        handleFolderAppDrop(payload: payload, targetApp: targetApp, zone: zone, folderID: folder.id)
                    },
                    onAppDraggedOut: { payload in
                        vm.removeApp(payload.itemID, fromFolder: folder.id)
                    },
                    onClose: vm.closeFolder
                )
                .padding(28)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }

            LaunchpadDragPreviewView()
        }
        .frame(width: config.paneWidth, height: config.paneHeight)
        .background {
            LaunchpadBackdropView(mode: .popup)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
        .environment(dragState)
        .onKeyPress(.escape) {
            if !vm.stepBack() { onDismissRequested() }
            return .handled
        }
        .missingAppAlert($missingApp) { vm.removeFromLayout($0) }
    }

    @ViewBuilder
    private func compactGrid(_ results: [LaunchpadItem]) -> some View {
        if results.isEmpty {
            ContentUnavailableView.search(text: vm.searchQuery)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let cols = [GridItem(.adaptive(minimum: config.iconSize + 16), spacing: 8, alignment: .top)]
            ScrollView {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(results) { item in
                        switch item {
                        case .app(let app):
                            AppIconView(
                                app: app,
                                icon: vm.icon(for: app.bundleID),
                                iconSize: config.iconSize * 0.75,
                                showLabel: config.iconLabelVisible,
                                isEditMode: false,
                                onTap: { launchAndDismiss(app) }
                            )
                        case .folder(let folder):
                            FolderView(
                                folder: folder,
                                iconSize: config.iconSize * 0.75,
                                showLabel: config.iconLabelVisible,
                                isEditMode: false,
                                iconProvider: { vm.icon(for: $0) },
                                onOpen: { vm.toggleFolder(folder.id) }
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
        vm.searchQuery = ""
        vm.closeFolder()
        onAppLaunched()
        dismiss()
    }

    private func openTopSearchResult() {
        switch vm.searchResults?.first {
        case .app(let app): launchAndDismiss(app)
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
}
