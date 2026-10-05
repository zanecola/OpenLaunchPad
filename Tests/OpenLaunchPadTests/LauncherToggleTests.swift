import Foundation
import Testing
@testable import OpenLaunchPad

struct LauncherToggleTests {
    private final class Clock {
        var time: TimeInterval = 1_000
    }

    private let clock = Clock()

    private func makeToggle() -> LauncherToggle {
        LauncherToggle(now: { [clock] in clock.time })
    }

    @Test
    func clickClosesAVisibleLauncher() {
        var toggle = makeToggle()

        let closes = toggle.clickCloses(launcherIsVisible: true)

        #expect(closes)
    }

    @Test
    func clickOpensAHiddenLauncher() {
        var toggle = makeToggle()

        let closes = toggle.clickCloses(launcherIsVisible: false)

        #expect(!closes)
    }

    @Test
    func clickClosesWhenItsMouseDownAlreadyDismissedTheLauncher() {
        var toggle = makeToggle()
        toggle.recordImplicitDismissal()
        clock.time += 0.15

        let closes = toggle.clickCloses(launcherIsVisible: false)

        #expect(closes)
    }

    @Test
    func clickOpensWhenTheDismissalIsOlderThanAClick() {
        var toggle = makeToggle()
        toggle.recordImplicitDismissal()
        clock.time += 0.5

        let closes = toggle.clickCloses(launcherIsVisible: false)

        #expect(!closes)
    }

    @Test
    func eachDismissalClosesOnlyOneClick() {
        var toggle = makeToggle()
        toggle.recordImplicitDismissal()
        clock.time += 0.1

        let first = toggle.clickCloses(launcherIsVisible: false)
        clock.time += 0.1
        let second = toggle.clickCloses(launcherIsVisible: false)

        #expect(first)
        #expect(!second)
    }

    @Test
    func closingAVisibleLauncherUsesUpAnEarlierDismissal() {
        var toggle = makeToggle()
        toggle.recordImplicitDismissal()

        let first = toggle.clickCloses(launcherIsVisible: true)
        let second = toggle.clickCloses(launcherIsVisible: false)

        #expect(first)
        #expect(!second)
    }
}
