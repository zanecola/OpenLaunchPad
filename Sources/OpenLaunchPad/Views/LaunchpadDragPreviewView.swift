import SwiftUI

struct LaunchpadDragPreviewView: View {
    @Environment(LaunchpadDragState.self) private var dragState
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(ConfigStore.self) private var config

    var body: some View {
        if let active = dragState.active {
            preview(for: active.item)
                .scaleEffect(1.12)
                .opacity(0.92)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
                .position(active.location)
                .allowsHitTesting(false)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .zIndex(100)
        }
    }

    @ViewBuilder
    private func preview(for item: LaunchpadItem) -> some View {
        switch item {
        case .app(let app):
            AppIconView(
                app: app,
                icon: vm.icon(for: app.bundleID),
                iconSize: config.iconSize,
                showLabel: config.iconLabelVisible,
                isEditMode: false,
                dragPayload: nil
            )
        case .folder(let folder):
            FolderView(
                folder: folder,
                iconSize: config.iconSize,
                showLabel: config.iconLabelVisible,
                isEditMode: false,
                iconProvider: { vm.icon(for: $0) },
                dragPayload: nil
            )
        }
    }
}
