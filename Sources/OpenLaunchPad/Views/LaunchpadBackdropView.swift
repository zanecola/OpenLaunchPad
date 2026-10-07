import AppKit
import SwiftUI

enum LaunchpadBackdropMode {
    case fullScreen
    case popup
}

struct LaunchpadBackdropView: View {
    let mode: LaunchpadBackdropMode
    /// The surface's choice, before Reduce Transparency or a missing wallpaper changes it.
    var style: BackdropStyle = .glass
    var wallpaper: WallpaperProvider.Status = .unavailable
    /// Black over the full-screen wallpaper or glass; the popup follows its appearance and is
    /// washed instead (`popupWash`).
    var dim: Double = 0
    /// Where the popup is on its screen, so its wallpaper lines up with the desktop under it.
    var screenSize: CGSize = .zero
    var frameInScreen: CGRect = .zero
    /// Fades in a wallpaper that arrives while the launcher shows; nil swaps it at once.
    var wallpaperFade: Animation? = nil
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private static let solidColor = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)

    /// Over the popup's wallpaper, so its text reads in either appearance: black under the dark
    /// appearance's light text, white under the light one's dark text. Measured offscreen over
    /// blurred desktop pictures, these keep labels at 4.5:1 or more and secondary text at 3:1 over
    /// the popup's median background; dark needs more because the search field's fill lightens it.
    private static func popupWash(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black.opacity(0.55) : .white.opacity(0.5)
    }

    var body: some View {
        ZStack {
            switch mode {
            case .fullScreen:
                switch style.resolved(reduceTransparency: reduceTransparency, wallpaperAvailable: wallpaper != .unavailable) {
                case .wallpaper:
                    // Opaque, so it stays under Reduce Transparency. The solid base shows until the
                    // render arrives, and between two renders as one fades into the next.
                    Self.solidColor
                    if case .ready(let rendered) = wallpaper {
                        WallpaperImage(image: rendered.image)
                            .id(rendered.id)
                            .transition(.opacity)
                    }
                    Color.black.opacity(dim)
                case .glass:
                    // The material stays at full opacity: fading it shows the desktop through unblurred.
                    VisualEffectBlur(material: .fullScreenUI, blendingMode: .behindWindow)
                    Color.black.opacity(dim)
                case .solid:
                    Self.solidColor
                }
            case .popup:
                let resolved = style.resolvedForPopup(wallpaperAvailable: wallpaper != .unavailable)
                if resolved == .solid {
                    Color(nsColor: .windowBackgroundColor)
                } else {
                    // One Glass is Wallpaper's base and its fallback, so a picture that becomes
                    // unavailable fades out over it rather than one Glass cross-fading into another.
                    // It shows until the render arrives, and between two renders as one fades into
                    // the next. The picture is opaque, so it stays under Reduce Transparency.
                    popupGlass
                    if resolved == .wallpaper, case .ready(let rendered) = wallpaper {
                        ZStack {
                            WallpaperCropImage(image: rendered.image, screenSize: screenSize, frameInScreen: frameInScreen)
                            Self.popupWash(for: colorScheme)
                        }
                        .id(rendered.id)
                        .transition(.opacity)
                    }
                }
            }
        }
        .animation(wallpaperFade, value: wallpaper)
    }

    @ViewBuilder
    private var popupGlass: some View {
        // NSVisualEffectView turns opaque by itself under Reduce Transparency.
        VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
        Color(nsColor: .windowBackgroundColor)
            .opacity(0.35)
    }
}

/// Aspect-fills its space without taking the image's size.
private struct WallpaperImage: View {
    let image: CGImage

    var body: some View {
        Color.clear
            .overlay {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .clipped()
    }
}

/// The part of the screen's wallpaper under a window: the cached render drawn at the size it fills
/// the screen, moved by the window's place on the screen and clipped to the window.
private struct WallpaperCropImage: View {
    let image: CGImage
    let screenSize: CGSize
    let frameInScreen: CGRect

    var body: some View {
        let rect = WallpaperCrop.imageRect(
            imageSize: CGSize(width: image.width, height: image.height),
            screenSize: screenSize,
            frameInScreen: frameInScreen
        )
        Color.clear
            .overlay(alignment: .topLeading) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
            }
            .clipped()
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
    }
}
