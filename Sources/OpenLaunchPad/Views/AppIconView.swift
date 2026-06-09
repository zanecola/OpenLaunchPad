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
    @Environment(LaunchpadDragState.self) private var dragState

    var body: some View {
        content
            .opacity(dragState.active?.payload.itemID == app.id ? 0.35 : 1)
            .launchpadGestureDrag(
                payload: dragPayload,
                item: .app(app),
                onDragChanged: onDragChanged,
                onDragEnded: onDragEnded
            )
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
