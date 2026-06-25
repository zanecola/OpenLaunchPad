import SwiftUI

/// Compact Launchpad panel shown when user clicks the menu bar icon.
/// Sized by paneWidth × paneHeight from ConfigStore.
struct MenuBarPanelView: View {
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(ConfigStore.self) private var config
    @Environment(\.dismiss) private var dismiss
    var onDismissRequested: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    @State private var dragState = LaunchpadDragState()

    var body: some View {
        @Bindable var vm = vm

        ZStack {
            VStack(spacing: 0) {
                SearchBarView(
                    text: $vm.searchQuery,
                    onOpenSettings: onOpenSettings
                )
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Divider()

                if let results = vm.searchResults {
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
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
        .environment(dragState)
    }

    private func compactGrid(_ results: [LaunchpadItem]) -> some View {
        let cols = [GridItem(.adaptive(minimum: config.iconSize + 16), spacing: 8, alignment: .top)]
        return ScrollView {
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(results) { item in
                    if case .app(let app) = item {
                        AppIconView(
                            app: app,
                            icon: vm.icon(for: app.bundleID),
                            iconSize: config.iconSize * 0.75,
                            showLabel: config.iconLabelVisible,
                            isEditMode: false,
                            onTap: { launchAndDismiss(app) }
                        )
                    }
                }
            }
            .padding(12)
        }
        .scrollIndicators(.hidden)
        .launchpadScrollAppearance()
    }

    private func launchAndDismiss(_ app: AppItem) {
        vm.launch(app)
        vm.searchQuery = ""
        vm.closeFolder()
        onDismissRequested()
        dismiss()
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
