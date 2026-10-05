import SwiftUI
import Testing
@testable import OpenLaunchPad

struct TilePressTests {
    @Test
    func aClickLooksPressedAndOpensOnRelease() {
        var press = TilePress()

        press.track(.zero, isControlClick: false)

        #expect(press.isPressed)
        #expect(press.opens(releasedAt: .zero))
    }

    @Test
    func aSlipShorterThanADragStillOpens() {
        var press = TilePress()
        press.track(.zero, isControlClick: false)

        press.track(CGSize(width: 5, height: 3), isControlClick: false)

        #expect(press.isPressed)
        #expect(press.opens(releasedAt: CGSize(width: 5, height: 3)))
    }

    @Test
    func movingAsFarAsADragEndsTheClickEvenIfThePointerComesBack() {
        var press = TilePress()
        press.track(.zero, isControlClick: false)

        press.track(CGSize(width: LaunchpadDragGestureModifier.minimumDistance, height: 0), isControlClick: false)
        #expect(!press.isPressed)

        press.track(CGSize(width: 1, height: 0), isControlClick: false)
        #expect(!press.isPressed)
        #expect(!press.opens(releasedAt: .zero))
    }

    @Test
    func releasingAwayFromThePressOpensNothing() {
        var press = TilePress()
        press.track(.zero, isControlClick: false)

        #expect(!press.opens(releasedAt: CGSize(width: 0, height: 30)))
    }

    @Test
    func aControlClickIsLeftToTheContextMenu() {
        var press = TilePress()

        press.track(.zero, isControlClick: true)

        #expect(!press.isPressed)
        #expect(!press.opens(releasedAt: .zero))
    }
}

struct TileFeedbackTests {
    @Test
    func aTileAtRestIsDrawnAsItIs() {
        #expect(TileFeedback(isPressed: false, reduceMotion: false) == TileFeedback(scale: 1, brightness: 0))
    }

    @Test
    func aPressedTileShrinksAndDarkens() {
        #expect(TileFeedback(isPressed: true, reduceMotion: false) == TileFeedback(scale: 0.92, brightness: -0.15))
    }

    @Test
    func reduceMotionKeepsAPressedTileAtItsSize() {
        #expect(TileFeedback(isPressed: true, reduceMotion: true) == TileFeedback(scale: 1, brightness: -0.15))
    }
}

struct TileMotionTests {
    @Test
    func aPressGoesDownQuicklyAndSpringsBack() {
        let motion = LaunchpadMotion()

        #expect(motion.tilePress(isPressed: true) == .easeOut(duration: 0.08))
        #expect(motion.tilePress(isPressed: false) == .spring(response: 0.25))
    }

    @Test
    func aPressFollowsTheSpeedAndReduceMotionButNotWithTransitionsOff() {
        let fast = LaunchpadMotion(speed: 2)
        #expect(fast.tilePress(isPressed: true) == .easeOut(duration: 0.04))
        #expect(fast.tilePress(isPressed: false) == .spring(response: 0.125))

        let reduced = LaunchpadMotion(reduceMotion: true)
        #expect(reduced.tilePress(isPressed: true) == .easeOut(duration: 0.08))

        let off = LaunchpadMotion(animatesTransitions: false)
        #expect(off.tilePress(isPressed: true) == nil)
        #expect(off.tilePress(isPressed: false) == nil)
    }
}
