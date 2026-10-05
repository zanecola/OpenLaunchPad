import SwiftUI

enum LaunchpadIconMetrics {
    static func labelFontSize(for iconSize: CGFloat) -> CGFloat {
        max(10, iconSize * 0.145)
    }

    static func labelHeight(for iconSize: CGFloat) -> CGFloat {
        ceil(labelFontSize(for: iconSize) * 2.4)
    }

    static func cellHeight(for iconSize: CGFloat, showsLabel: Bool) -> CGFloat {
        guard showsLabel else { return iconSize }
        return max(iconSize + 40, iconSize + 6 + labelHeight(for: iconSize))
    }
}

enum LaunchpadLabelStyle {
    /// White with a shadow, over the always-dark full-screen backdrop.
    case onDarkBackdrop
    /// The adaptive label color, over the popup, which can be light or dark.
    case adaptive
}

extension EnvironmentValues {
    @Entry var launchpadLabelStyle: LaunchpadLabelStyle = .adaptive
}

struct LaunchpadIconLabel: View {
    let title: String
    let iconSize: CGFloat
    @Environment(\.launchpadLabelStyle) private var style

    var body: some View {
        Text(title)
            .font(.system(size: LaunchpadIconMetrics.labelFontSize(for: iconSize)))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .foregroundStyle(style == .onDarkBackdrop ? Color.white : Color.primary)
            .shadow(color: style == .onDarkBackdrop ? .black.opacity(0.6) : .clear, radius: 2)
            .frame(
                width: iconSize + 16,
                height: LaunchpadIconMetrics.labelHeight(for: iconSize),
                alignment: .top
            )
    }
}
