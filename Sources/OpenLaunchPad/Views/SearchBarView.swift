import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    var onClear: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.title3)
                .onSubmit { onClear() }  // pressing Return dismisses search

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
