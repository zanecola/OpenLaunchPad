import SwiftUI

@Observable
final class LaunchpadDragState {
    var active: ActiveLaunchpadDrag?

    var isDragging: Bool {
        active != nil
    }

    func begin(payload: LaunchpadDragPayload, item: LaunchpadItem, at location: CGPoint) {
        active = ActiveLaunchpadDrag(payload: payload, item: item, location: location)
    }

    func move(to location: CGPoint) {
        active?.location = location
    }

    func end() {
        active = nil
    }
}

struct ActiveLaunchpadDrag: Identifiable {
    let payload: LaunchpadDragPayload
    let item: LaunchpadItem
    var location: CGPoint

    var id: UUID { payload.itemID }
}

struct LaunchpadDragGestureModifier: ViewModifier {
    let payload: LaunchpadDragPayload?
    let item: LaunchpadItem?
    var onDragChanged: (LaunchpadDragPayload, CGPoint) -> Void
    var onDragEnded: (LaunchpadDragPayload, CGPoint) -> Void
    @Environment(LaunchpadDragState.self) private var dragState

    func body(content: Content) -> some View {
        if let payload, let item {
            content.highPriorityGesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .onChanged { value in
                        if dragState.active?.payload != payload {
                            dragState.begin(payload: payload, item: item, at: value.location)
                        } else {
                            dragState.move(to: value.location)
                        }
                        onDragChanged(payload, value.location)
                    }
                    .onEnded { value in
                        dragState.end()
                        onDragEnded(payload, value.location)
                    }
            )
        } else {
            content
        }
    }
}

struct LaunchpadItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

extension View {
    func launchpadGestureDrag(
        payload: LaunchpadDragPayload?,
        item: LaunchpadItem?,
        onDragChanged: @escaping (LaunchpadDragPayload, CGPoint) -> Void = { _, _ in },
        onDragEnded: @escaping (LaunchpadDragPayload, CGPoint) -> Void
    ) -> some View {
        modifier(LaunchpadDragGestureModifier(
            payload: payload,
            item: item,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded
        ))
    }

    func launchpadItemFrame(id: UUID) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: LaunchpadItemFramePreferenceKey.self,
                    value: [id: proxy.frame(in: .global)]
                )
            }
        }
    }
}
