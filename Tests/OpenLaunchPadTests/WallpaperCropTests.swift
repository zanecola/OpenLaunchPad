import AppKit
import Testing
@testable import OpenLaunchPad

struct WallpaperCropTests {
    @Test
    func aPictureOfTheScreensShapeFillsItExactly() {
        let rect = WallpaperCrop.aspectFillRect(imageSize: CGSize(width: 2560, height: 1440), screenSize: CGSize(width: 1280, height: 720))

        #expect(rect == CGRect(x: 0, y: 0, width: 1280, height: 720))
    }

    @Test
    func aRetinaScreensRenderFillsItInPoints() {
        // A 1512 x 982 pt built-in display (3024 x 1964 pixels) renders at a quarter pixel per
        // point for the default blur; the rounding leaves the picture a little taller than the screen.
        let screen = CGSize(width: 1512, height: 982)
        let request = WallpaperRequest(sources: [], screenSize: screen, blurRadius: 48)
        let image = CGSize(width: request.pixelWidth, height: request.pixelHeight)

        let rect = WallpaperCrop.aspectFillRect(imageSize: image, screenSize: screen)

        #expect(image == CGSize(width: 378, height: 246))
        #expect(rect == CGRect(x: 0, y: -1, width: 1512, height: 984))
    }

    @Test
    func aPortraitPictureOnALandscapeScreenIsCenteredVertically() {
        let rect = WallpaperCrop.aspectFillRect(imageSize: CGSize(width: 100, height: 200), screenSize: CGSize(width: 1600, height: 900))

        #expect(rect == CGRect(x: 0, y: -1150, width: 1600, height: 3200))
    }

    @Test
    func aLandscapePictureOnAPortraitScreenIsCenteredHorizontally() {
        let rect = WallpaperCrop.aspectFillRect(imageSize: CGSize(width: 400, height: 225), screenSize: CGSize(width: 1080, height: 1920))

        #expect(abs(rect.height - 1920) < 0.001)
        #expect(abs(rect.width - 3413.333) < 0.001)
        #expect(abs(rect.minX - -1166.667) < 0.001)
        #expect(rect.minY == 0)
    }

    @Test
    func theFrameIsMeasuredFromTheTopLeftOfAScreenRightOfAndBelowThePrimary() {
        // An external display to the right of the built-in one, its top 200 pt below the primary's.
        let screen = CGRect(x: 1512, y: -658, width: 2560, height: 1440)
        let window = CGRect(x: 3000, y: 100, width: 860, height: 620)

        let frame = WallpaperCrop.frameInScreen(windowFrame: window, screenFrame: screen)

        #expect(frame == CGRect(x: 1488, y: 62, width: 860, height: 620))
    }

    @Test
    func theFrameIsMeasuredFromTheTopLeftOfAScreenLeftOfThePrimary() {
        let screen = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let window = CGRect(x: -1000, y: 300, width: 800, height: 600)

        #expect(WallpaperCrop.frameInScreen(windowFrame: window, screenFrame: screen) == CGRect(x: 920, y: 180, width: 800, height: 600))
    }

    @Test
    func thePopupShowsThePartOfThePictureUnderIt() {
        let screenFrame = CGRect(x: 1512, y: -658, width: 2560, height: 1440)
        let image = CGSize(width: 640, height: 360)
        let window = CGRect(x: 3000, y: 100, width: 860, height: 620)
        let frame = WallpaperCrop.frameInScreen(windowFrame: window, screenFrame: screenFrame)

        let rect = WallpaperCrop.imageRect(imageSize: image, screenSize: screenFrame.size, frameInScreen: frame)

        #expect(rect == CGRect(x: -1488, y: -62, width: 2560, height: 1440))
        // A point on the screen falls on the same spot of the picture in full screen and the popup.
        let fill = WallpaperCrop.aspectFillRect(imageSize: image, screenSize: screenFrame.size)
        let point = CGPoint(x: 1700, y: 400)
        let inPopup = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
        #expect(CGPoint(x: point.x - fill.minX, y: point.y - fill.minY) == CGPoint(x: inPopup.x - rect.minX, y: inPopup.y - rect.minY))
    }

    @Test
    func aPopupAtTheScreensEdgesIsCoveredByThePicture() {
        // The built-in display with a 34 pt menu bar and the Dock on the left.
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let visibleFrame = CGRect(x: 61, y: 0, width: 1451, height: 948)
        let panelSize = CGSize(width: 860, height: 620)
        let image = CGSize(width: 378, height: 246)
        let anchors = [
            CGPoint(x: 1490, y: 950),  // a status item at the right end of the menu bar
            CGPoint(x: 30, y: 900),  // the top of the Dock
            CGPoint(x: 30, y: 20)  // the bottom of the Dock
        ]

        for anchor in anchors {
            let origin = PopupPlacement.origin(anchor: anchor, panelSize: panelSize, screenFrame: screenFrame, visibleFrame: visibleFrame)
            let frame = WallpaperCrop.frameInScreen(windowFrame: CGRect(origin: origin, size: panelSize), screenFrame: screenFrame)
            let rect = WallpaperCrop.imageRect(imageSize: image, screenSize: screenFrame.size, frameInScreen: frame)

            #expect(rect.contains(CGRect(origin: .zero, size: panelSize)))
        }

        let menuBar = PopupPlacement.origin(anchor: anchors[0], panelSize: panelSize, screenFrame: screenFrame, visibleFrame: visibleFrame)
        let frame = WallpaperCrop.frameInScreen(windowFrame: CGRect(origin: menuBar, size: panelSize), screenFrame: screenFrame)
        #expect(frame == CGRect(x: 644, y: 42, width: 860, height: 620))
        // The picture's right edge is 8 pt past the panel's, where the screen ends.
        #expect(WallpaperCrop.imageRect(imageSize: image, screenSize: screenFrame.size, frameInScreen: frame) == CGRect(x: -644, y: -43, width: 1512, height: 984))
    }

    @Test
    func anEmptyImageCoversTheScreen() {
        #expect(WallpaperCrop.aspectFillRect(imageSize: .zero, screenSize: CGSize(width: 800, height: 600)) == CGRect(x: 0, y: 0, width: 800, height: 600))
    }
}

@MainActor
struct WallpaperPlacementTests {
    @Test
    func aPlacementIsTheScreenAndTheFrameFromItsTopLeft() {
        let placement = WallpaperPlacement()
        #expect(placement.screenID == nil)

        placement.update(
            screenID: "DISPLAY-2",
            screenFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
            windowFrame: CGRect(x: -1000, y: 300, width: 800, height: 600)
        )

        #expect(placement.screenID == "DISPLAY-2")
        #expect(placement.screenSize == CGSize(width: 1920, height: 1080))
        #expect(placement.frameInScreen == CGRect(x: 920, y: 180, width: 800, height: 600))
    }

    @Test
    func placingTheWindowWhereItWasRedrawsNothing() {
        let placement = WallpaperPlacement()
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let window = CGRect(x: 644, y: 320, width: 860, height: 620)
        placement.update(screenID: "DISPLAY-1", screenFrame: screen, windowFrame: window)

        let read = { _ = (placement.screenID, placement.screenSize, placement.frameInScreen) }
        #expect(!observationFires(when: { placement.update(screenID: "DISPLAY-1", screenFrame: screen, windowFrame: window) }, reading: read))
        #expect(observationFires(when: { placement.update(screenID: "DISPLAY-1", screenFrame: screen, windowFrame: window.offsetBy(dx: -100, dy: 0)) }, reading: read))
    }
}
