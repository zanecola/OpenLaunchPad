import SwiftUI

struct LaunchpadDragGestureModifier: ViewModifier {
    let payload: LaunchpadDragPayload?
    var onDragEnded: (LaunchpadDragPayload, CGPoint) -> Void

    func body(content: Content) -> some View {
        if let payload {
            content.highPriorityGesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .onEnded { value in
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
        onDragEnded: @escaping (LaunchpadDragPayload, CGPoint) -> Void
    ) -> some View {
        modifier(LaunchpadDragGestureModifier(
            payload: payload,
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
