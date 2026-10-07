import AppKit
import SwiftUI
import Testing
@testable import OpenLaunchPad

@MainActor
struct LaunchpadBackdropViewTests {
    @Test
    func thePopupsGlassStaysThroughEveryWallpaperStatus() throws {
        // A replaced glass would cross-fade with its replacement, which shows the windows behind
        // the popup through both.
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
        // Pending draws the glass alone. It is layers, not a view.
        let glass = try layers(in: #require(host.layer)).filter { $0 !== host.layer }
        let materials = effectViews(in: host)

        var seen: [Set<ObjectIdentifier>] = []
        for status: WallpaperProvider.Status in [.ready(BackdropWallpaper(id: 1, image: picture)), .unavailable, .pending] {
            host.rootView = backdrop(status)
            host.layoutSubtreeIfNeeded()
            seen.append(Set(try layers(in: #require(host.layer)).map(ObjectIdentifier.init)))
        }
        window.contentView = nil

        #expect(!glass.isEmpty)
        // A single glass surface: no material under it, as the popover material used to be.
        #expect(materials.isEmpty)
        for layers in seen {
            #expect(glass.allSatisfy { layers.contains(ObjectIdentifier($0)) })
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

    @Test
    func thePopupsFolderPanelIsAPlainFillOnlyOverGlass() {
        // A material on the glass would stack one blur on another.
        #expect(LaunchpadBackdropView.popupFolderPanel(style: .glass) == .fill)
        #expect(LaunchpadBackdropView.popupFolderPanel(style: .wallpaper) == .material)
        #expect(LaunchpadBackdropView.popupFolderPanel(style: .solid) == .material)
    }

    private func layers(in layer: CALayer) -> [CALayer] {
        [layer] + (layer.sublayers ?? []).flatMap(layers)
    }

    private func effectViews(in view: NSView) -> [NSVisualEffectView] {
        view.subviews.flatMap { subview in
            (subview as? NSVisualEffectView).map { [$0] } ?? effectViews(in: subview)
        }
    }
}
