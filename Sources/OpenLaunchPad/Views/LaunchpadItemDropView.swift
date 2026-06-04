import SwiftUI

struct LaunchpadItemDropModifier: ViewModifier {
    let target: LaunchpadItem
    let targetWidth: CGFloat
    var isEnabled = true
    var onDrop: (LaunchpadDragPayload, LaunchpadItem, DropZone) -> Bool

    @State private var activeZone: DropZone?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: overlayAlignment) {
                dropIndicator
            }
            .dropDestination(for: LaunchpadDragPayload.self) { payloads, location in
                guard isEnabled,
                      let payload = payloads.first,
                      payload.itemID != target.id else {
                    return false
                }

                let zone = DropZone.classify(x: location.x, width: targetWidth)
                return onDrop(payload, target, zone)
            } isTargeted: { isTargeted in
                activeZone = isTargeted ? .center : nil
            }
    }

    private var overlayAlignment: Alignment {
        switch activeZone {
        case .leading: return .leading
        case .trailing: return .trailing
        case .center, nil: return .center
        }
    }

    @ViewBuilder
    private var dropIndicator: some View {
        if let activeZone {
            switch activeZone {
            case .leading, .trailing:
                Capsule()
                    .fill(.white.opacity(0.8))
                    .frame(width: 4, height: targetWidth * 0.72)
            case .center:
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.45), lineWidth: 2)
                    .frame(width: targetWidth, height: targetWidth)
            }
        }
    }
}

extension View {
    func launchpadItemDropTarget(
        target: LaunchpadItem,
        targetWidth: CGFloat,
        isEnabled: Bool = true,
        onDrop: @escaping (LaunchpadDragPayload, LaunchpadItem, DropZone) -> Bool
    ) -> some View {
        modifier(LaunchpadItemDropModifier(
            target: target,
            targetWidth: targetWidth,
            isEnabled: isEnabled,
            onDrop: onDrop
        ))
    }
}
