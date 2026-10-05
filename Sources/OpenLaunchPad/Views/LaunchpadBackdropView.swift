import AppKit
import SwiftUI

enum LaunchpadBackdropMode {
    case fullScreen
    case popup
}

struct LaunchpadBackdropView: View {
    let mode: LaunchpadBackdropMode
    /// Full screen's choice, before Reduce Transparency or a missing wallpaper changes it.
    var style: BackdropStyle = .glass
    var wallpaper: WallpaperProvider.Status = .unavailable
    /// Black over the full-screen wallpaper or glass; the popup follows the system appearance
    /// and is not dimmed.
    var dim: Double = 0
    /// Fades in a wallpaper that arrives while full screen shows; nil swaps it at once.
    var wallpaperFade: Animation? = nil
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private static let solidColor = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)

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
                // NSVisualEffectView turns opaque by itself under Reduce Transparency.
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                Color(nsColor: .windowBackgroundColor)
                    .opacity(0.35)
            }
        }
        .animation(wallpaperFade, value: wallpaper)
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
