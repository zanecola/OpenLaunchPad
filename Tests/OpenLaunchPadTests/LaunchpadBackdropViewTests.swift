import AppKit
import SwiftUI
import Testing
@testable import OpenLaunchPad

@MainActor
struct LaunchpadBackdropViewTests {
    @Test
    func thePopupsGlassStaysThroughEveryWallpaperStatus() throws {
        // A replaced material would cross-fade with its replacement, which shows the windows
        // behind the popup through both.
        let picture = try #require(CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )?.makeImage())
        func backdrop(_ status: WallpaperProvider.Status) -> LaunchpadBackdropView {
            LaunchpadBackdropView(mode: .popup, style: .wallpaper, wallpaper: status)
        }
        let host = NSHostingView(rootView: backdrop(.pending))
        host.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        // Never shown; borderless, so it can't become key.
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let glass = effectViews(in: host)

        var seen: [[NSVisualEffectView]] = []
        for status: WallpaperProvider.Status in [.ready(BackdropWallpaper(id: 1, image: picture)), .unavailable, .pending] {
            host.rootView = backdrop(status)
            host.layoutSubtreeIfNeeded()
            seen.append(effectViews(in: host))
        }
        window.contentView = nil

        #expect(glass.count == 1)
        for views in seen {
            #expect(views.map(ObjectIdentifier.init) == glass.map(ObjectIdentifier.init))
        }
    }

    @Test
    func thePopupsFolderDimStaysLightUnderDarkTextOverTheWallpaper() {
        // The light wash keeps the picture at or above 60% gray; a 15% dim leaves the folder's
        // name, in 85% black, at 4.8:1 or more there.
        #expect(LaunchpadBackdropView.popupFolderDim(style: .wallpaper, colorScheme: .light) == 0.15)
        #expect(LaunchpadBackdropView.popupFolderDim(style: .wallpaper, colorScheme: .dark) == 0.35)
        for style in [BackdropStyle.glass, .solid] {
            for colorScheme in [ColorScheme.light, .dark] {
                #expect(LaunchpadBackdropView.popupFolderDim(style: style, colorScheme: colorScheme) == 0.35)
            }
        }
    }

    private func effectViews(in view: NSView) -> [NSVisualEffectView] {
        view.subviews.flatMap { subview in
            (subview as? NSVisualEffectView).map { [$0] } ?? effectViews(in: subview)
        }
    }
}
