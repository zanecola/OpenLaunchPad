import Foundation
import Testing
@testable import OpenLaunchPad

@MainActor
struct ApplicationManagerTests {
    @Test
    func protectsSystemAndCurrentApplicationsButAllowsRegularApps() {
        #expect(SystemApplicationManager.isProtectedApplication(
            at: URL(fileURLWithPath: "/System/Applications/Safari.app")
        ))
        #expect(SystemApplicationManager.isProtectedApplication(at: Bundle.main.bundleURL))
        #expect(!SystemApplicationManager.isProtectedApplication(
            at: URL(fileURLWithPath: "/Applications/Example.app")
        ))
    }
}
