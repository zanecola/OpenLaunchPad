import SwiftUI
import AppKit

struct AppIconView: View {
    let app: AppItem
    let icon: NSImage
    let iconSize: Double
    let showLabel: Bool
    let isEditMode: Bool
    var dragPayload: LaunchpadDragPayload?
    var onDragChanged: (LaunchpadDragPayload, CGPoint) -> Void = { _, _ in }
    var onDragEnded: (LaunchpadDragPayload, CGPoint) -> Void = { _, _ in }
    var onTap: () -> Void = {}

    @State private var hover = LauncherHover()
    @State private var wiggleAngle: Double = 0
    @State private var uninstallRequest: UninstallRequest?
    @State private var actionError: String?
    @Environment(LaunchpadDragState.self) private var dragState
    @Environment(LaunchpadViewModel.self) private var vm

    var body: some View {
        content
            .opacity(dragState.active?.payload.itemID == app.id ? 0.35 : 1)
            .launchpadGestureDrag(
                payload: dragPayload,
                item: .app(app),
                onDragChanged: onDragChanged,
                onDragEnded: onDragEnded
            )
            .contextMenu { appContextMenu }
            .confirmationDialog(
                "Uninstall \(app.title)?",
                isPresented: Binding(
                    get: { uninstallRequest != nil },
                    set: { if !$0 { uninstallRequest = nil } }
                ),
                presenting: uninstallRequest
            ) { _ in
                Button("Move to Trash", role: .destructive, action: uninstall)
                Button("Cancel", role: .cancel) {}
            } message: { request in
                Text(request.message)
            }
            .alert(
                "Couldn’t Complete Action",
                isPresented: Binding(
                    get: { actionError != nil },
                    set: { if !$0 { actionError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(actionError ?? "Unknown error")
            }
    }

    @ViewBuilder
    private var appContextMenu: some View {
        Button("Open", action: onTap)

        Divider()

        Button("Show in Finder") {
            perform { try vm.revealInFinder(app) }
        }

        Button("Get Info") {
            perform { try vm.showInfo(app) }
        }

        Divider()

        let uninstallURL = vm.uninstallURL(for: app)
        Button("Uninstall…", role: .destructive) {
            // Asked only here: it is a LaunchServices query, and menus rebuild with every render.
            uninstallRequest = uninstallURL.map { UninstallRequest(url: $0, otherCopies: vm.otherCopyURLs(of: app)) }
        }
        .disabled(uninstallURL == nil)
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func uninstall() {
        perform { try vm.uninstall(app) }
    }

    private var content: some View {
        let isHovered = hover.isActive(in: vm.presentationID)
        return VStack(spacing: 6) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: iconSize, height: iconSize)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                .rotationEffect(.degrees(isEditMode ? wiggleAngle : 0))
                .scaleEffect(isHovered && !isEditMode ? 1.08 : 1.0)

            if showLabel {
                LaunchpadIconLabel(title: app.title, iconSize: CGFloat(iconSize))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { hover.update(isHovering: $0, presentationID: vm.presentationID) }
        .animation(.spring(duration: 0.15), value: hover)
        .onChange(of: isEditMode) { _, editing in
            if editing { startWiggle() } else { wiggleAngle = 0 }
        }
        // One named button per tile, even with labels hidden; the context menu stays available.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(app.title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onTap)
    }

    private func startWiggle() {
        // Stagger wiggle phase so all icons don't sync
        let phase = Double.random(in: 0...(.pi * 2))
        let amplitude = Double.random(in: 1.5...2.5)
        withAnimation(.linear(duration: 0.12).repeatForever(autoreverses: true).delay(phase * 0.04)) {
            wiggleAngle = amplitude
        }
    }
}

/// The bundle Uninstall moves to the Trash, and the copies it leaves installed.
private struct UninstallRequest {
    let url: URL
    let otherCopies: [URL]

    var message: String {
        var message = "\(Self.displayPath(url)) will be moved to the Trash. Your documents and app data will not be removed."
        if !otherCopies.isEmpty {
            message += "\n\nThese copies stay installed:\n" + otherCopies.map(Self.displayPath).joined(separator: "\n")
        }
        return message
    }

    private static func displayPath(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}
