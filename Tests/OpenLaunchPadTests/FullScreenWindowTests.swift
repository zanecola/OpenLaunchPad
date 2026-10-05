import AppKit
import SwiftUI
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

    @Test
    func contentKeepsOutOfTheMenuBarAndABottomDock() {
        let insets = FullScreenWindow.contentInsets(
            screenFrame: CGRect(x: 0, y: 0, width: 1_512, height: 982),
            visibleFrame: CGRect(x: 0, y: 70, width: 1_512, height: 874),
            safeAreaInsets: NSEdgeInsets(top: 32, left: 0, bottom: 0, right: 0),
            autoHidesDockAndMenuBar: false
        )

        #expect(insets == EdgeInsets(top: 38, leading: 0, bottom: 70, trailing: 0))
    }

    @Test
    func contentKeepsOutOfASideDockOnASecondaryDisplay() {
        let insets = FullScreenWindow.contentInsets(
            screenFrame: CGRect(x: -1_920, y: 0, width: 1_920, height: 1_080),
            visibleFrame: CGRect(x: -1_920, y: 0, width: 1_850, height: 1_056),
            safeAreaInsets: NSEdgeInsets(),
            autoHidesDockAndMenuBar: false
        )

        #expect(insets == EdgeInsets(top: 24, leading: 0, bottom: 0, trailing: 70))
    }

    @Test
    func cameraHousingStillCountsWhenTheMenuBarIsHidden() {
        let insets = FullScreenWindow.contentInsets(
            screenFrame: CGRect(x: 0, y: 0, width: 1_512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_512, height: 982),
            safeAreaInsets: NSEdgeInsets(top: 32, left: 0, bottom: 0, right: 0),
            autoHidesDockAndMenuBar: false
        )

        #expect(insets.top == 32)
    }

    @Test
    func autoHidingLeavesOnlyTheCameraHousing() {
        let insets = FullScreenWindow.contentInsets(
            screenFrame: CGRect(x: 0, y: 0, width: 1_512, height: 982),
            visibleFrame: CGRect(x: 0, y: 70, width: 1_512, height: 874),
            safeAreaInsets: NSEdgeInsets(top: 32, left: 0, bottom: 0, right: 0),
            autoHidesDockAndMenuBar: true
        )

        #expect(insets == EdgeInsets(top: 32, leading: 0, bottom: 0, trailing: 0))
    }
}
