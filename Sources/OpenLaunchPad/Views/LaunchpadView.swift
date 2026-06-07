import SwiftUI

/// Full-screen Launchpad overlay — blur backdrop, search, grid, page dots.
struct LaunchpadView: View {
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(ConfigStore.self) private var config
    var onDismiss: () -> Void = {}

    var body: some View {
        @Bindable var vm = vm

        ZStack {
            // Backdrop — clicks outside folder overlay close the folder or dismiss
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if vm.expandedFolderID != nil {
                        vm.closeFolder()
                    } else if vm.isEditMode {
                        vm.toggleEditMode()
                    } else {
                        onDismiss()
                    }
                }

            VStack(spacing: 0) {
                // Search bar
                SearchBarView(text: $vm.searchQuery, onClear: vm.closeFolder)
                    .padding(.top, 40)
                    .padding(.bottom, 24)

                // Content: search results or paginated grid
                if let results = vm.searchResults {
                    searchResultsView(results)
                } else {
                    AppGridView(
                        mode: .paged,
                        onLaunch: { app in
                            vm.launch(app)
                            onDismiss()
                        }
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Page indicator (hidden during search)
                if vm.searchResults == nil && vm.pages.count > 1 {
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
                    onLaunch: { app in vm.launch(app); onDismiss() },
                    onRename: { vm.renameFolder(folder.id, to: $0) },
                    onAppDrop: { payload, targetApp, zone in
                        handleFolderAppDrop(payload: payload, targetApp: targetApp, zone: zone, folderID: folder.id)
                    },
                    onAppDraggedOut: { payload in
                        vm.removeApp(payload.itemID, fromFolder: folder.id)
                    },
                    onClose: vm.closeFolder
                )
                .animation(.spring(duration: 0.3 * config.animationSpeed), value: folder.id)
            }
        }
        .background(backdrop)
        .ignoresSafeArea()
        .onKeyPress(.escape) {
            if vm.expandedFolderID != nil {
                vm.closeFolder()
            } else if vm.isEditMode {
                vm.toggleEditMode()
            } else {
                onDismiss()
            }
            return .handled
        }
        .onKeyPress(.leftArrow) {
            vm.showPreviousPage()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            vm.showNextPage()
            return .handled
        }
        .task { await vm.load() }
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

    private func searchResultsView(_ results: [LaunchpadItem]) -> some View {
        let cols = Array(repeating: GridItem(.fixed(config.iconSize + 24), spacing: 12), count: 7)
        return ScrollView {
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
                            onTap: { vm.launch(app); onDismiss() }
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
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var backdrop: some View {
        ZStack {
            VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
            Color.black.opacity(min(0.14 + config.backgroundBlur / 400, 0.28))
        }
        .ignoresSafeArea()
    }
}

// MARK: - NSVisualEffectView bridge (ADR-6 fallback)

import AppKit

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
