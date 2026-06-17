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

    @State private var isHovered = false
    @State private var wiggleAngle: Double = 0
    @State private var showsUninstallConfirmation = false
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
                isPresented: $showsUninstallConfirmation
            ) {
                Button("Move to Trash", role: .destructive, action: uninstall)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The application will be moved to the Trash. Your documents and app data will not be removed.")
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

        Button("Uninstall…", role: .destructive) {
            showsUninstallConfirmation = true
        }
        .disabled(!vm.canUninstall(app))
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
        VStack(spacing: 6) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: iconSize, height: iconSize)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                .rotationEffect(.degrees(isEditMode ? wiggleAngle : 0))
                .scaleEffect(isHovered && !isEditMode ? 1.08 : 1.0)

            if showLabel {
                Text(app.title)
                    .font(.system(size: max(10, iconSize * 0.145)))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .frame(maxWidth: iconSize + 16)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { isHovered = $0 }
        .animation(.spring(duration: 0.15), value: isHovered)
        .onChange(of: isEditMode) { _, editing in
            if editing { startWiggle() } else { wiggleAngle = 0 }
        }
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
