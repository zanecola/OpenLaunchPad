import SwiftUI

struct PageIndicatorView: View {
    let pageCount: Int
    @Binding var currentPage: Int

    var body: some View {
        HStack(spacing: 6) {
            pageButton(systemName: "chevron.left", page: currentPage - 1)
                .disabled(currentPage == 0)

            ForEach(0..<pageCount, id: \.self) { index in
                Button {
                    currentPage = index
                } label: {
                    Circle()
                        .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.38))
                        .frame(width: index == currentPage ? 8 : 6, height: index == currentPage ? 8 : 6)
                        .frame(width: 22, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Page \(index + 1)")
                .accessibilityAddTraits(index == currentPage ? .isSelected : [])
            }

            pageButton(systemName: "chevron.right", page: currentPage + 1)
                .disabled(currentPage >= pageCount - 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .animation(.spring(duration: 0.2), value: currentPage)
    }

    private func pageButton(systemName: String, page: Int) -> some View {
        Button {
            currentPage = min(max(page, 0), pageCount - 1)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
