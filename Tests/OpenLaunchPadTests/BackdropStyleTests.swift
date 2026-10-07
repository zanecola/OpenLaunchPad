import Testing
@testable import OpenLaunchPad

struct BackdropStyleTests {
    @Test
    func wallpaperStaysUnderReduceTransparency() {
        #expect(BackdropStyle.wallpaper.resolved(reduceTransparency: false, wallpaperAvailable: true) == .wallpaper)
        #expect(BackdropStyle.wallpaper.resolved(reduceTransparency: true, wallpaperAvailable: true) == .wallpaper)
    }

    @Test
    func wallpaperWithoutAPictureFallsBackAsGlassDoes() {
        #expect(BackdropStyle.wallpaper.resolved(reduceTransparency: false, wallpaperAvailable: false) == .glass)
        #expect(BackdropStyle.wallpaper.resolved(reduceTransparency: true, wallpaperAvailable: false) == .solid)
    }

    @Test
    func glassNeedsTransparencyAndSolidIsAlwaysSolid() {
        #expect(BackdropStyle.glass.resolved(reduceTransparency: false, wallpaperAvailable: true) == .glass)
        #expect(BackdropStyle.glass.resolved(reduceTransparency: true, wallpaperAvailable: true) == .solid)
        for reduceTransparency in [false, true] {
            #expect(BackdropStyle.solid.resolved(reduceTransparency: reduceTransparency, wallpaperAvailable: true) == .solid)
        }
    }

    @Test
    func thePopupKeepsItsChoiceUnderReduceTransparency() {
        // Its glass is a material that turns opaque by itself, and the wallpaper is opaque.
        for style in BackdropStyle.allCases {
            #expect(style.resolvedForPopup(wallpaperAvailable: true) == style)
        }
    }

    @Test
    func thePopupWithoutAPictureFallsBackToGlass() {
        #expect(BackdropStyle.wallpaper.resolvedForPopup(wallpaperAvailable: false) == .glass)
        #expect(BackdropStyle.glass.resolvedForPopup(wallpaperAvailable: false) == .glass)
        #expect(BackdropStyle.solid.resolvedForPopup(wallpaperAvailable: false) == .solid)
    }
}
