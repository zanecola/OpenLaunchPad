import Foundation
import Testing
@testable import OpenLaunchPad

struct LaunchpadDragStateTests {
    private let mail = AppItem(id: UUID(), bundleID: "com.example.Mail", title: "Mail")

    @Test
    func pointerMovesInvalidateThePreviewButNotTheTiles() {
        let state = LaunchpadDragState()
        state.begin(payload: LaunchpadDragPayload(itemID: mail.id, kind: .app), item: .app(mail), at: .zero)

        #expect(!observationFires(
            when: { state.move(to: CGPoint(x: 10, y: 10)) },
            reading: { _ = state.active?.payload.itemID }
        ))
        #expect(observationFires(
            when: { state.move(to: CGPoint(x: 20, y: 30)) },
            reading: { _ = state.location }
        ))
        #expect(state.location == CGPoint(x: 20, y: 30))
    }

    @Test
    func beginAndEndInvalidateTheTiles() {
        let state = LaunchpadDragState()
        let payload = LaunchpadDragPayload(itemID: mail.id, kind: .app)

        #expect(observationFires(
            when: { state.begin(payload: payload, item: .app(mail), at: CGPoint(x: 5, y: 5)) },
            reading: { _ = state.active?.payload.itemID }
        ))
        #expect(state.active?.payload == payload)
        #expect(state.location == CGPoint(x: 5, y: 5))

        #expect(observationFires(
            when: { state.end() },
            reading: { _ = state.active?.payload.itemID }
        ))
        #expect(state.active == nil)
    }
}
