import AppKit
import Testing
@testable import OpenLaunchPad

@MainActor
struct AppDelegateTests {
    @Test
    func aTitledWindowKeepsTheAppActiveAfterADismissal() {
        let settings = StubWindow(styleMask: [.titled], isVisible: true)

        #expect(AppDelegate.showsOtherWindow(in: [settings]))
    }

    @Test
    func aDialogOnTheClosingLauncherDoesNotKeepTheAppActive() {
        let launcher = StubWindow(styleMask: [.borderless], isVisible: true)
        let dialog = StubWindow(styleMask: [.titled], isVisible: true, sheetParent: launcher)

        #expect(!AppDelegate.showsOtherWindow(in: [launcher, dialog]))
    }

    @Test
    func aTitledWindowOffScreenDoesNotKeepTheAppActive() {
        let settings = StubWindow(styleMask: [.titled], isVisible: false)

        #expect(!AppDelegate.showsOtherWindow(in: [settings]))
    }
}

/// Reports visibility and a sheet parent without putting a window on screen.
private final class StubWindow: NSWindow {
    private let stubIsVisible: Bool
    private weak var stubSheetParent: NSWindow?

    init(styleMask: NSWindow.StyleMask, isVisible: Bool, sheetParent: NSWindow? = nil) {
        stubIsVisible = isVisible
        stubSheetParent = sheetParent
        super.init(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: styleMask, backing: .buffered, defer: true)
    }

    override var isVisible: Bool { stubIsVisible }
    override var sheetParent: NSWindow? { stubSheetParent }
}
