import Testing
@testable import OpenLaunchPad

struct LauncherHoverTests {
    @Test
    func hoverCountsDuringTheShowItBeganIn() {
        var hover = LauncherHover()

        hover.update(isHovering: true, presentationID: 3)

        #expect(hover.isActive(in: 3))
    }

    @Test
    func hoverLeftFromAnEarlierShowDoesNotCount() {
        var hover = LauncherHover()

        hover.update(isHovering: true, presentationID: 3)

        #expect(!hover.isActive(in: 4))
    }

    @Test
    func pointerLeavingEndsTheHover() {
        var hover = LauncherHover()
        hover.update(isHovering: true, presentationID: 3)

        hover.update(isHovering: false, presentationID: 3)

        #expect(!hover.isActive(in: 3))
    }

    @Test
    func viewThatIsNotHoveredNeverReadsThePresentation() {
        let hover = LauncherHover()
        var reads = 0

        let isActive = hover.isActive(in: {
            reads += 1
            return 3
        }())

        #expect(!isActive)
        #expect(reads == 0)
    }
}
