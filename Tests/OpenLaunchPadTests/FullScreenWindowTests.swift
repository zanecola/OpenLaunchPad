import AppKit
import Testing
@testable import OpenLaunchPad

@MainActor
struct FullScreenWindowTests {
    @Test
    func windowDoesNotFloatAboveOtherApplicationsOrJoinEverySpace() {
        let window = FullScreenWindow()

        #expect(window.level == .normal)
        #expect(!window.collectionBehavior.contains(.canJoinAllSpaces))
    }

    @Test
    func windowIsDarkWhateverTheSystemAppearance() {
        #expect(FullScreenWindow().appearance?.name == .darkAqua)
    }
}
