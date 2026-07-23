import Testing
@testable import OpenLaunchPad

struct FrequentlyUsedAppsLayoutTests {
    @Test
    func wideLayoutCapsTheStripAtSevenApps() {
        let layout = FrequentlyUsedAppsLayout(
            width: 1600,
            configuredIconSize: 96,
            showsLabels: true,
            presentation: .fullScreen
        )

        #expect(layout.visibleCount == 7)
        #expect(layout.iconSize == 80)
    }

    @Test
    func narrowPopupReducesCountAndCapsIconSize() {
        let layout = FrequentlyUsedAppsLayout(
            width: 400,
            configuredIconSize: 128,
            showsLabels: true,
            presentation: .popup
        )

        #expect(layout.visibleCount == 3)
        #expect(layout.iconSize == 72)
        #expect(layout.spacing >= 12)
    }
}
