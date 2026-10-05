import SwiftUI

extension View {
    /// Shown when a tile's app was moved or deleted, so the launch could not happen.
    func missingAppAlert(_ app: Binding<AppItem?>, onRemove: @escaping (AppItem) -> Void) -> some View {
        alert(
            "\(app.wrappedValue?.title ?? "The app") can’t be found.",
            isPresented: Binding(
                get: { app.wrappedValue != nil },
                set: { if !$0 { app.wrappedValue = nil } }
            ),
            presenting: app.wrappedValue
        ) { missingApp in
            Button("Remove from Layout", role: .destructive) { onRemove(missingApp) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It may have been moved or deleted.")
        }
    }
}
