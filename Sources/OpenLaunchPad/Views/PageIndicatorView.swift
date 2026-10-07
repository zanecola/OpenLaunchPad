import SwiftUI

/// Full screen's page control: bare white dots on the dark backdrop, as Launchpad drew them. The
/// current one follows the pages as they scroll. With Dots + Arrows, pointing at it fades in a
/// capsule with previous and next arrows. VoiceOver reads it as one adjustable element,
/// "Page, N of M".
struct PageIndicatorView: View {
    static let dotDiameter: CGFloat = 7
    /// Side by side, the dots' hit boxes leave 9 pt between dots.
    static let dotBoxSize = CGSize(width: 16, height: 20)
    private static let arrowBoxSize = CGSize(width: 20, height: 28)

    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(ConfigStore.self) private var config
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.launchpadMotion) private var motion
    @State private var hover = LauncherHover()

    var body: some View {
        let style = config.pageControlStyle
        let showsArrows = style.showsArrows(whileHovered: hover.isActive(in: vm.presentationID))
        let pageCount = vm.pages.count
        let currentPage = min(max(vm.currentPage, 0), max(pageCount - 1, 0))

        HStack(spacing: 0) {
            // Laid out even while hidden, so the dots stay put when the arrows appear.
            if style == .dotsAndArrows {
                arrow("chevron.backward", isEnabled: currentPage > 0, action: vm.showPreviousPage)
                    .opacity(showsArrows ? 1 : 0)
            }

            HStack(spacing: 0) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Button {
                        vm.currentPage = index
                    } label: {
                        Self.dot
                            .opacity(0.35)
                            .frame(width: Self.dotBoxSize.width, height: Self.dotBoxSize.height)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(alignment: .leading) {
                CurrentPageDot(pageCount: pageCount)
            }

            if style == .dotsAndArrows {
                arrow("chevron.forward", isEnabled: currentPage < pageCount - 1, action: vm.showNextPage)
                    .opacity(showsArrows ? 1 : 0)
            }
        }
        .padding(.horizontal, style == .dotsAndArrows ? 4 : 0)
        .background { arrowsBackground(isVisible: showsArrows) }
        .animation(motion.controlHover, value: hover)
        .onHover { hover.update(isHovering: $0, presentationID: vm.presentationID) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page")
        .accessibilityValue("\(currentPage + 1) of \(pageCount)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: vm.showNextPage()
            case .decrement: vm.showPreviousPage()
            @unknown default: break
            }
        }
    }

    static var dot: some View {
        Circle()
            .fill(.white)
            .frame(width: dotDiameter, height: dotDiameter)
            // The labels' shadow, which sets the dots off a light wallpaper. Flattened, so a dimmed
            // dot dims its shadow rather than showing it through.
            .shadow(color: .black.opacity(0.6), radius: 2)
            .compositingGroup()
    }

    /// How far the current dot sits from the first one at a scroll `position` in pages. It stays
    /// on the end dots while the pages rubber-band past them.
    static func currentDotOffset(position: Double, pageCount: Int) -> CGFloat {
        CGFloat(min(max(position, 0), Double(max(pageCount - 1, 0)))) * dotBoxSize.width
    }

    private func arrow(_ systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.3))
                .frame(width: Self.arrowBoxSize.width, height: Self.arrowBoxSize.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    @ViewBuilder
    private func arrowsBackground(isVisible: Bool) -> some View {
        if reduceTransparency {
            // Opaque, a step above the solid backdrop, like the Frequently Used shelf.
            Capsule()
                .fill(Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255))
                .opacity(isVisible ? 1 : 0)
        } else {
            Color.clear.glassEffect(isVisible ? .regular : .identity, in: .capsule)
        }
    }
}

/// The only part of the page control that reads the scroll position, so a swipe redraws just
/// this dot. It moves with the pages: with the fingers, and with a page turn's spring, which is
/// instant under Reduce Motion.
private struct CurrentPageDot: View {
    @Environment(LaunchpadViewModel.self) private var vm
    let pageCount: Int

    var body: some View {
        PageIndicatorView.dot
            .frame(width: PageIndicatorView.dotBoxSize.width, height: PageIndicatorView.dotBoxSize.height)
            .offset(x: PageIndicatorView.currentDotOffset(position: vm.pagePosition, pageCount: pageCount))
            .allowsHitTesting(false)
    }
}
