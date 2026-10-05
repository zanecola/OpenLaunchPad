import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    /// Glass over the full-screen backdrop; a filled, outlined field in the popup, so it reads in
    /// either appearance.
    let backdrop: LaunchpadBackdropMode
    var onClear: () -> Void = {}
    var onSubmit: () -> Void = {}
    @FocusState private var isFocused: Bool

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
                // Hosts are rebuilt on every show, so this focuses search each time the launcher opens.
                .onAppear { isFocused = true }

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
        .background { fieldBackground }
    }

    @ViewBuilder
    private var fieldBackground: some View {
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
    @State private var isHovered = false

    var body: some View {
        let diameter: CGFloat = backdrop == .fullScreen ? 30 : 28
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: diameter / 2, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: diameter, height: diameter)
                .glassEffect(.regular.interactive(), in: .circle)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(backdrop == .fullScreen && !isHovered ? 0.55 : 1)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .help("Open Settings")
        .accessibilityLabel("Open Settings")
    }
}
