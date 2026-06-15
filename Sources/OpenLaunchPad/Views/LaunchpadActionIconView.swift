import SwiftUI

struct LaunchpadActionIconView: View {
    let title: String
    let systemImage: String
    let iconSize: CGFloat
    let showLabel: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(nsColor: .controlColor), Color(nsColor: .underPageBackgroundColor)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }

                Image(systemName: systemImage)
                    .font(.system(size: iconSize * 0.48, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
            }
            .frame(width: iconSize, height: iconSize)
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            .scaleEffect(isHovered ? 1.08 : 1)

            if showLabel {
                Text(title)
                    .font(.system(size: max(10, iconSize * 0.145)))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .frame(maxWidth: iconSize + 16)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { isHovered = $0 }
        .animation(.spring(duration: 0.15), value: isHovered)
        .accessibilityAddTraits(.isButton)
    }
}
