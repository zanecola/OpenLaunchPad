import SwiftUI
import Testing
@testable import OpenLaunchPad

struct LaunchpadMotionTests {
    @Test
    func fullScreenZoomsInOnASpringAndOutAsItFades() {
        let motion = LaunchpadMotion()

        #expect(motion.fullScreenShow == WindowTransition(
            duration: 0.18,
            curve: .easeOut,
            scale: 1.06,
            spring: WindowTransition.Spring(response: 0.32, dampingFraction: 0.88)
        ))
        #expect(motion.fullScreenClose == WindowTransition(duration: 0.14, curve: .easeIn, scale: 1.04))
    }

    @Test
    func launchingOnlyFadesSoTheOpeningAppIsNotCovered() {
        #expect(LaunchpadMotion().fullScreenLaunch == WindowTransition(duration: 0.12, curve: .easeIn))
    }

    @Test
    func popupGrowsInAndFadesOut() {
        let motion = LaunchpadMotion()

        #expect(motion.popupShow == WindowTransition(duration: 0.16, curve: .easeOut, scale: 0.96))
        #expect(motion.popupClose == WindowTransition(duration: 0.12, curve: .easeIn))
    }

    @Test
    func speedDividesDurationsAndTheSpringResponse() {
        let motion = LaunchpadMotion(speed: 2)

        #expect(motion.duration(0.3) == 0.15)
        #expect(motion.fullScreenShow?.duration == 0.09)
        #expect(motion.fullScreenShow?.spring == WindowTransition.Spring(response: 0.16, dampingFraction: 0.88))
        #expect(motion.popupClose?.duration == 0.06)
    }

    @Test
    func reduceMotionKeepsTheFadesWithoutScaling() {
        let motion = LaunchpadMotion(reduceMotion: true)

        #expect(motion.fullScreenShow == WindowTransition(duration: 0.18, curve: .easeOut))
        #expect(motion.fullScreenClose == WindowTransition(duration: 0.14, curve: .easeIn))
        #expect(motion.popupShow == WindowTransition(duration: 0.16, curve: .easeOut))
        #expect(motion.animation(0.22) { .easeInOut(duration: $0) } != nil)
        #expect(motion.movement(0.3) { .spring(duration: $0) } == nil)
    }

    @Test
    func transitionsOffMakeEverythingInstant() {
        let motion = LaunchpadMotion(animatesTransitions: false)

        #expect(motion.duration(0.3) == nil)
        #expect(motion.fullScreenShow == nil)
        #expect(motion.fullScreenClose == nil)
        #expect(motion.fullScreenLaunch == nil)
        #expect(motion.popupShow == nil)
        #expect(motion.popupClose == nil)
        #expect(motion.animation(0.22) { .easeInOut(duration: $0) } == nil)
        #expect(motion.movement(0.3) { .spring(duration: $0) } == nil)
    }

    @Test
    func foldersZoomOnASpringAndCrossfadeUnderReduceMotion() {
        #expect(LaunchpadMotion().folderZoom == .spring(response: 0.35, dampingFraction: 0.86))
        #expect(LaunchpadMotion(speed: 2).folderZoom == .spring(response: 0.175, dampingFraction: 0.86))
        #expect(LaunchpadMotion().folderBackdropFade == .easeOut(duration: 0.22))

        let reduced = LaunchpadMotion(reduceMotion: true)
        #expect(reduced.folderZoom == .easeInOut(duration: 0.22))
        #expect(reduced.folderBackdropFade == .easeOut(duration: 0.22))

        let off = LaunchpadMotion(animatesTransitions: false)
        #expect(off.folderZoom == nil)
        #expect(off.folderBackdropFade == nil)
    }

    @Test
    func readsTheAnimationSettings() {
        let config = ConfigStore(defaults: InMemoryKeyValueStore())
        config.animatesTransitions = false
        config.animationSpeed = 1.5

        let motion = LaunchpadMotion(config: config, reduceMotion: true)

        #expect(motion == LaunchpadMotion(animatesTransitions: false, speed: 1.5, reduceMotion: true))
    }
}
