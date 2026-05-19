import SwiftUI

/// Compact Launchpad panel shown when user clicks the menu bar icon.
/// Sized by paneWidth × paneHeight from ConfigStore.
struct MenuBarPanelView: View {
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(ConfigStore.self) private var config
    @Environment(\.dismiss) private var dismiss
    var onDismissRequested: () -> Void = {}

    var body: some View {
        @Bindable var vm = vm

        ZStack {
            VStack(spacing: 0) {
                SearchBarView(text: $vm.searchQuery)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Divider()

                if let results = vm.searchResults {
                    compactGrid(results)
                } else {
                    AppGridView(mode: .scrolling, onLaunch: launchAndDismiss)
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
                    onClose: vm.closeFolder
                )
                .padding(28)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .frame(width: config.paneWidth, height: config.paneHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
        .task { await vm.load() }
    }

    private func compactGrid(_ results: [LaunchpadItem]) -> some View {
        let cols = Array(repeating: GridItem(.fixed(config.iconSize + 16), spacing: 8), count: 5)
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
    }

    private func launchAndDismiss(_ app: AppItem) {
        vm.launch(app)
        vm.searchQuery = ""
        vm.closeFolder()
        onDismissRequested()
        dismiss()
    }
}
