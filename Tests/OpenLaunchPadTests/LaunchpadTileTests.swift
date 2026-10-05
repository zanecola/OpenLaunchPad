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
    @Test(arguments: TileHoverEffect.allCases)
    func aTileAtRestIsDrawnAsItIs(effect: TileHoverEffect) {
        let feedback = TileFeedback(isPressed: false, isHovered: false, hoverEffect: effect, reduceMotion: false)

        #expect(feedback == TileFeedback(scale: 1, brightness: 0, showsHighlight: false))
    }

    @Test(arguments: TileHoverEffect.allCases)
    func aPressedTileShrinksAndDarkens(effect: TileHoverEffect) {
        let feedback = TileFeedback(isPressed: true, isHovered: true, hoverEffect: effect, reduceMotion: false)

        #expect(feedback.scale == 0.92)
        #expect(feedback.brightness == -0.15)
    }

    @Test
    func reduceMotionKeepsAPressedTileAtItsSize() {
        let feedback = TileFeedback(isPressed: true, isHovered: true, hoverEffect: .lift, reduceMotion: true)

        #expect(feedback.scale == 1)
        #expect(feedback.brightness == -0.15)
    }

    @Test
    func highlightDrawsAPlateWhileHoveredAndPressed() {
        #expect(TileFeedback(isPressed: false, isHovered: true, hoverEffect: .highlight, reduceMotion: false)
            == TileFeedback(scale: 1, brightness: 0, showsHighlight: true))
        #expect(TileFeedback(isPressed: true, isHovered: true, hoverEffect: .highlight, reduceMotion: true).showsHighlight)
    }

    @Test
    func liftGrowsTheHoveredTileExceptUnderReduceMotion() {
        #expect(TileFeedback(isPressed: false, isHovered: true, hoverEffect: .lift, reduceMotion: false)
            == TileFeedback(scale: 1.04, brightness: 0, showsHighlight: false))
        #expect(TileFeedback(isPressed: false, isHovered: true, hoverEffect: .lift, reduceMotion: true)
            == TileFeedback(scale: 1, brightness: 0, showsHighlight: false))
    }

    @Test
    func noHoverEffectLeavesTheHoveredTileAlone() {
        #expect(TileFeedback(isPressed: false, isHovered: true, hoverEffect: .off, reduceMotion: false)
            == TileFeedback(scale: 1, brightness: 0, showsHighlight: false))
    }
}

struct TileMotionTests {
    @Test
    func aPressGoesDownQuicklyAndSpringsBack() {
        let motion = LaunchpadMotion()

        #expect(motion.tilePress(isPressed: true) == .easeOut(duration: 0.08))
        #expect(motion.tilePress(isPressed: false) == .spring(response: 0.25))
        #expect(motion.tileHover == .easeOut(duration: 0.12))
    }

    @Test
    func tileFeedbackFollowsTheSpeedAndReduceMotionButNotWithTransitionsOff() {
        let fast = LaunchpadMotion(speed: 2)
        #expect(fast.tilePress(isPressed: true) == .easeOut(duration: 0.04))
        #expect(fast.tilePress(isPressed: false) == .spring(response: 0.125))
        #expect(fast.tileHover == .easeOut(duration: 0.06))

        let reduced = LaunchpadMotion(reduceMotion: true)
        #expect(reduced.tilePress(isPressed: true) == .easeOut(duration: 0.08))
        #expect(reduced.tileHover == .easeOut(duration: 0.12))

        let off = LaunchpadMotion(animatesTransitions: false)
        #expect(off.tilePress(isPressed: true) == nil)
        #expect(off.tilePress(isPressed: false) == nil)
        #expect(off.tileHover == nil)
    }
}
