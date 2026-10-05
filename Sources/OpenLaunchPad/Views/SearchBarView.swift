import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    /// Glass over the full-screen backdrop; a filled, outlined field in the popup, so it reads in
    /// either appearance.
    let backdrop: LaunchpadBackdropMode
    var onClear: () -> Void = {}
    var onSubmit: () -> Void = {}
    @FocusState private var isFocused: Bool
    @Environment(LaunchpadViewModel.self) private var vm

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($isFocused)
                .onSubmit(onSubmit)
                // The launcher stays alive between shows, so each show focuses search again.
                .onChange(of: vm.presentationID, initial: true) { isFocused = true }
                // Renaming a folder takes focus; typing searches again once the name is done.
                .onChange(of: vm.folderTitleDraft == nil) { _, isDone in
                    if isDone { isFocused = true }
                }

            if !text.isEmpty {
                Button(action: { text = ""; onClear() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear Search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: backdrop == .fullScreen ? 36 : 32)
        .background { LaunchpadFieldBackground(backdrop: backdrop) }
    }
}

/// A text field's capsule: glass over the full-screen backdrop; filled and outlined in the
/// popup, so it reads in either appearance.
struct LaunchpadFieldBackground: View {
    let backdrop: LaunchpadBackdropMode

    var body: some View {
        switch backdrop {
        case .fullScreen:
            Color.clear.glassEffect(.regular, in: .capsule)
        case .popup:
            Capsule()
                .fill(.quaternary)
                .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
        }
    }
}

/// Opens Settings. In full screen it rests faded in the top-trailing corner, out of the way.
struct SettingsButton: View {
    let backdrop: LaunchpadBackdropMode
    let action: () -> Void
    @State private var hover = LauncherHover()
    @Environment(LaunchpadViewModel.self) private var vm

    var body: some View {
        let diameter: CGFloat = backdrop == .fullScreen ? 30 : 28
        let isHovered = hover.isActive(in: vm.presentationID)
        Button(action: action) {
            let symbol = Image(systemName: "gearshape.fill")
                .font(.system(size: diameter / 2, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: diameter, height: diameter)
            switch backdrop {
            case .fullScreen:
                symbol
                    .glassEffect(.regular.interactive(), in: .circle)
                    .contentShape(Circle())
            case .popup:
                // Glass draws the symbol white, which vanishes on the light popup, so it matches
                // the search field beside it instead.
                symbol
                    .foregroundStyle(isHovered ? .primary : .secondary)
                    .background {
                        Circle()
                            .fill(.quaternary)
                            .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))
                    }
                    .contentShape(Circle())
            }
        }
        .buttonStyle(.plain)
        .opacity(backdrop == .fullScreen && !isHovered ? 0.55 : 1)
        .animation(.easeOut(duration: 0.15), value: hover)
        .onHover { hover.update(isHovering: $0, presentationID: vm.presentationID) }
        .help("Open Settings")
        .accessibilityLabel("Open Settings")
    }
}
