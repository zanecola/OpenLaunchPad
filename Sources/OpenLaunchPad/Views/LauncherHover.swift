/// A hover that ends with the show it began in. A launcher that is ordered out sends its views no
/// hover exit, so without this the tile under the pointer at close would still look hovered the
/// next time the launcher opens. Views animate on the hover itself (`value: hover`), so a hover
/// dropped by a new show snaps back rather than shrinking in view.
struct LauncherHover: Equatable {
    private var presentationID: Int?

    mutating func update(isHovering: Bool, presentationID: Int) {
        self.presentationID = isHovering ? presentationID : nil
    }

    /// Reads the current presentation only while hovered, so a new show re-renders just the
    /// hovered view rather than every tile.
    func isActive(in currentPresentationID: @autoclosure () -> Int) -> Bool {
        guard let presentationID else { return false }
        return presentationID == currentPresentationID()
    }
}
