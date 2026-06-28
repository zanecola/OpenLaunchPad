import AppKit
import SwiftUI

enum LaunchpadBackdropMode {
    case fullScreen
    case popup
}

enum LaunchpadBackdropMetrics {
    static func intensity(for blurAmount: Double) -> Double {
        min(max(blurAmount / 60, 0), 1)
    }
}

struct LaunchpadBackdropView: View {
    let mode: LaunchpadBackdropMode
    let blurAmount: Double

    private var intensity: Double {
        LaunchpadBackdropMetrics.intensity(for: blurAmount)
    }

    var body: some View {
        ZStack {
            VisualEffectBlur(
                material: mode == .fullScreen ? .underWindowBackground : .popover,
                blendingMode: .behindWindow
            )
            .opacity(intensity)

            switch mode {
            case .fullScreen:
                Color.black.opacity(0.14 + intensity * 0.12)
            case .popup:
                Color(nsColor: .windowBackgroundColor)
                    .opacity(1 - intensity * 0.58)
                Color.black.opacity(intensity * 0.08)
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
