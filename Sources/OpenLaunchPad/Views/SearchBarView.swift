import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    var onClear: () -> Void = {}
    var onSubmit: () -> Void = {}
    var onOpenSettings: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            searchField

            if let onOpenSettings {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Open Settings")
                .accessibilityLabel("Open Settings")
            }
        }
        .frame(maxWidth: onOpenSettings == nil ? 400 : 450)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.title3)
                .onSubmit(onSubmit)

            if !text.isEmpty {
                Button(action: { text = ""; onClear() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .frame(maxWidth: 400)
    }
}
