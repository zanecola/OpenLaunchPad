import Foundation
import Testing
@testable import OpenLaunchPad

struct WallpaperRequestTests {
    @Test
    func theRenderIsAsCoarseAsItsBlurAllows() {
        #expect(WallpaperRequest.pixelsPerPoint(blurRadius: 80) == 0.25)
        #expect(WallpaperRequest.pixelsPerPoint(blurRadius: 48) == 0.25)
        #expect(WallpaperRequest.pixelsPerPoint(blurRadius: 24) == 0.5)
        #expect(WallpaperRequest.pixelsPerPoint(blurRadius: 12) == 1)
        #expect(WallpaperRequest.pixelsPerPoint(blurRadius: 4) == 1)
        #expect(WallpaperRequest.pixelsPerPoint(blurRadius: 0) == 1)
    }

    @Test
    func theDefaultBlurIsTwelveRenderedPixelsOnAQuarterSizeImage() {
        let request = WallpaperRequest(sources: [], screenSize: CGSize(width: 1512, height: 982), blurRadius: 48)

        #expect(request.pixelWidth == 378)
        #expect(request.pixelHeight == 246)
        #expect(request.blurSigma == 12)
    }

    @Test
    func noBlurRendersAtOnePixelPerPoint() {
        let request = WallpaperRequest(sources: [], screenSize: CGSize(width: 1280, height: 800), blurRadius: 0)

        #expect(request.pixelWidth == 1280)
        #expect(request.pixelHeight == 800)
        #expect(request.blurSigma == 0)
    }
}

@MainActor
struct WallpaperProviderTests {
    private let screenSize = CGSize(width: 160, height: 100)
    private let display = "DISPLAY-1"

    @Test
    func aRenderIsReusedUntilSomethingChanges() async throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        let picture = try fixture.writePicture("Pictures/Beach.png")
        let provider = WallpaperProvider(resolver: fixture.resolver)
        let screen = WallpaperScreen(id: display, size: screenSize, desktopImageURL: picture)

        #expect(provider.status(for: display) == .pending)
        await provider.refresh(for: screen, blurRadius: 48)?.value
        let first = try #require(wallpaper(provider.status(for: display)))
        #expect(first.image.width == 40)
        #expect(first.image.height == 25)

        #expect(provider.refresh(for: screen, blurRadius: 48) == nil)
        #expect(provider.status(for: display) == .ready(first))

        await provider.refresh(for: screen, blurRadius: 24)?.value
        let reblurred = try #require(wallpaper(provider.status(for: display)))
        #expect(reblurred != first)
        #expect(reblurred.image.width == 80)

        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: 60)], ofItemAtPath: picture.path)
        await provider.refresh(for: screen, blurRadius: 24)?.value
        #expect(wallpaper(provider.status(for: display)).map { $0 != reblurred } == true)
    }

    @Test
    func thePreviousRenderStaysUpUntilTheNextArrives() async throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        let picture = try fixture.writePicture("Pictures/Beach.png")
        let provider = WallpaperProvider(resolver: fixture.resolver)
        let screen = WallpaperScreen(id: display, size: screenSize, desktopImageURL: picture)
        await provider.refresh(for: screen, blurRadius: 48)?.value
        let first = provider.status(for: display)

        let render = provider.refresh(for: screen, blurRadius: 24, delay: .milliseconds(50))

        #expect(provider.status(for: display) == first)
        // Asking again while it waits neither restarts it nor drops it.
        #expect(provider.refresh(for: screen, blurRadius: 24) == render)
        await render?.value
        #expect(provider.status(for: display) != first)
        #expect(wallpaper(provider.status(for: display)) != nil)
    }

    @Test
    func eachDisplayKeepsItsOwnRender() async throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        let beach = try fixture.writePicture("Pictures/Beach.png")
        let forest = try fixture.writePicture("Pictures/Forest.png", width: 80, height: 80)
        let provider = WallpaperProvider(resolver: fixture.resolver)
        let builtIn = WallpaperScreen(id: display, size: screenSize, desktopImageURL: beach)
        let external = WallpaperScreen(id: "DISPLAY-2", size: screenSize, desktopImageURL: forest)

        await provider.refresh(for: builtIn, blurRadius: 48)?.value
        let builtInRender = provider.status(for: display)
        await provider.refresh(for: external, blurRadius: 48)?.value

        #expect(wallpaper(provider.status(for: "DISPLAY-2")) != nil)
        #expect(provider.status(for: "DISPLAY-2") != builtInRender)
        // Rendering the other display left this one's picture up.
        #expect(provider.status(for: display) == builtInRender)
        #expect(provider.refresh(for: builtIn, blurRadius: 48) == nil)
    }

    @Test
    func aRefreshForAnotherDisplayDoesNotCancelThisOnesRender() async throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        let beach = try fixture.writePicture("Pictures/Beach.png")
        let forest = try fixture.writePicture("Pictures/Forest.png", width: 80, height: 80)
        let provider = WallpaperProvider(resolver: fixture.resolver)

        // Full screen opens on one display while the popup opens on the other.
        let fullScreen = provider.refresh(for: WallpaperScreen(id: display, size: screenSize, desktopImageURL: beach), blurRadius: 48, delay: .milliseconds(50))
        let popup = provider.refresh(for: WallpaperScreen(id: "DISPLAY-2", size: screenSize, desktopImageURL: forest), blurRadius: 48)
        #expect(provider.status(for: display) == .pending)
        await fullScreen?.value
        await popup?.value

        #expect(wallpaper(provider.status(for: display)) != nil)
        #expect(wallpaper(provider.status(for: "DISPLAY-2")) != nil)
        #expect(provider.status(for: display) != provider.status(for: "DISPLAY-2"))
    }

    @Test
    func noDisplayIsPending() {
        #expect(WallpaperProvider().status(for: nil) == .pending)
    }

    @Test
    func nothingToDrawIsUnavailableAtOnce() throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        let provider = WallpaperProvider(resolver: fixture.resolver)
        let screen = WallpaperScreen(id: display, size: screenSize, desktopImageURL: fixture.root.appendingPathComponent("Gone.heic"))

        #expect(provider.refresh(for: screen, blurRadius: 48) == nil)
        #expect(provider.status(for: display) == .unavailable)
    }

    @Test
    func aFileThatDoesNotDecodeIsUnavailable() async throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        let broken = try fixture.writeFile("Pictures/Broken.heic", contents: Data("not an image".utf8))
        let provider = WallpaperProvider(resolver: fixture.resolver)

        await provider.refresh(for: WallpaperScreen(id: display, size: screenSize, desktopImageURL: broken), blurRadius: 48)?.value

        #expect(provider.status(for: display) == .unavailable)
    }

    @Test
    func anAerialWhoseVideoDoesNotDecodeUsesItsPreview() async throws {
        let assetID = "AB7FC3C3-8853-45CD-AB6E-89F0985C2922"
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        try fixture.writeStore(["AllSpacesAndDisplays": WallpaperFixture.aerial(assetID)])
        try fixture.writeFile("idleassetsd/Customer/4KSDR/\(assetID).mov", contents: Data("not a movie".utf8))
        try fixture.writePicture("idleassetsd/snapshots/asset-preview-\(assetID).jpg", width: 214, height: 130)
        let provider = WallpaperProvider(resolver: fixture.resolver)

        await provider.refresh(for: WallpaperScreen(id: display, size: screenSize, desktopImageURL: fixture.placeholder), blurRadius: 48)?.value

        #expect(wallpaper(provider.status(for: display))?.image.width == 40)
    }

    private func wallpaper(_ status: WallpaperProvider.Status) -> BackdropWallpaper? {
        if case .ready(let wallpaper) = status { wallpaper } else { nil }
    }
}
