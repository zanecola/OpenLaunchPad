import SwiftUI

/// A value that lasts for the show it was set in, such as what a tile's dialog is about. Both
/// launchers stay alive between shows, so without this a dialog still open when the launcher
/// closed would be back on the next show, holding the keyboard instead of Search.
struct ShowScoped<Value> {
    private var value: Value?
    private var presentationID = 0

    mutating func set(_ value: Value?, presentationID: Int) {
        self.value = value
        self.presentationID = presentationID
    }

    mutating func clear() {
        value = nil
    }

    /// Reads the current presentation only while a value is set, so a show re-renders just the
    /// views that hold one rather than every tile.
    func value(in currentPresentationID: @autoclosure () -> Int) -> Value? {
        guard let value, presentationID == currentPresentationID() else { return nil }
        return value
    }
}

extension View {
    /// Runs `action` when a show begins, to clear what the last show left behind.
    func onLauncherShow(_ action: @escaping () -> Void) -> some View {
        modifier(OnLauncherShow(action: action))
    }
}

/// A modifier of its own, so a show re-renders only it.
private struct OnLauncherShow: ViewModifier {
    @Environment(LaunchpadViewModel.self) private var vm
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: vm.presentationID) { action() }
    }
}
