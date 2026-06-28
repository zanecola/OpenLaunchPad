import Testing
@testable import OpenLaunchPad

struct LaunchpadBackdropTests {
    @Test(arguments: [
        (-10.0, 0.0),
        (0.0, 0.0),
        (30.0, 0.5),
        (60.0, 1.0),
        (90.0, 1.0)
    ])
    func blurIntensityIsNormalizedAndClamped(input: Double, expected: Double) {
        #expect(LaunchpadBackdropMetrics.intensity(for: input) == expected)
    }
}
