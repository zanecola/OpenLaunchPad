import AppKit
import SwiftUI

enum LaunchpadBackdropMode {
    case fullScreen
    case popup
}

struct LaunchpadBackdropView: View {
    let mode: LaunchpadBackdropMode
    /// Black over the full-screen blur; the popup follows the system appearance and is not dimmed.
    var dim: Double = 0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            switch mode {
            case .fullScreen:
                if reduceTransparency {
                    Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
                } else {
                    // The material stays at full opacity: fading it shows the desktop through unblurred.
                    VisualEffectBlur(material: .fullScreenUI, blendingMode: .behindWindow)
                    Color.black.opacity(dim)
                }
            case .popup:
                // NSVisualEffectView turns opaque by itself under Reduce Transparency.
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                Color(nsColor: .windowBackgroundColor)
                    .opacity(0.35)
            }
        }
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
