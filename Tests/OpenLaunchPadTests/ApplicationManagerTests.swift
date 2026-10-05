import Foundation
import Testing
@testable import OpenLaunchPad

@MainActor
struct ApplicationManagerTests {
    @Test
    func uninstallTrashesTheScannedCopyRatherThanLaunchServicesPreferredOne() throws {
        let fixture = try BundleFixture()
        defer { fixture.remove() }
        let preferred = try fixture.addBundle("Preferred/Foo.app", bundleID: "com.example.foo")
        let scanned = try fixture.addBundle("Scanned/Foo.app", bundleID: "com.example.foo")
        let recorder = TrashRecorder()
        let manager = fixture.manager(registeredURLs: [preferred], recorder: recorder)
        let app = Self.app("Foo", "com.example.foo", at: scanned)

        #expect(manager.uninstallURL(for: app) == scanned.resolvingSymlinksInPath())
        try manager.uninstall(app)

        #expect(recorder.trashed == [scanned.resolvingSymlinksInPath()])
    }

    @Test
    func withoutAScannedCopyUninstallNeedsExactlyOneRegisteredCopy() throws {
        let fixture = try BundleFixture()
        defer { fixture.remove() }
        let first = try fixture.addBundle("A/Foo.app", bundleID: "com.example.foo")
        let second = try fixture.addBundle("B/Foo.app", bundleID: "com.example.foo")
        let app = Self.app("Foo", "com.example.foo", at: nil)

        let recorder = TrashRecorder()
        let ambiguous = fixture.manager(registeredURLs: [first, second], recorder: recorder)
        #expect(ambiguous.uninstallURL(for: app) == nil)
        #expect(throws: ApplicationManagerError.self) { try ambiguous.uninstall(app) }
        #expect(recorder.trashed.isEmpty)

        #expect(fixture.manager(registeredURLs: []).uninstallURL(for: app) == nil)

        let single = fixture.manager(registeredURLs: [second], recorder: recorder)
        #expect(single.uninstallURL(for: app) == second.resolvingSymlinksInPath())
        try single.uninstall(app)
        #expect(recorder.trashed == [second.resolvingSymlinksInPath()])
    }

    @Test
    func missingScannedCopyIsNotFoundEvenWhenAnotherCopyIsRegistered() throws {
        let fixture = try BundleFixture()
        defer { fixture.remove() }
        let other = try fixture.addBundle("Other/Foo.app", bundleID: "com.example.foo")
        let deleted = fixture.root.appendingPathComponent("Deleted/Foo.app", isDirectory: true)
        let recorder = TrashRecorder()
        // LaunchServices would offer the other copy, so falling back to it fails this test.
        let manager = fixture.manager(registeredURLs: [other], recorder: recorder)
        let app = Self.app("Foo", "com.example.foo", at: deleted)

        #expect(manager.uninstallURL(for: app) == nil)
        #expect(throws: ApplicationManagerError.self) { try manager.uninstall(app) }
        #expect(recorder.trashed.isEmpty)
        #expect(throws: ApplicationManagerError.self) { try manager.launch(app) }
        #expect(throws: ApplicationManagerError.self) { try manager.revealInFinder(app) }
        #expect(throws: ApplicationManagerError.self) { try manager.showInfo(app) }
    }

    @Test
    func otherCopiesAreTheExistingRegisteredOnesBesidesTheUninstallTarget() throws {
        let fixture = try BundleFixture()
        defer { fixture.remove() }
        let scanned = try fixture.addBundle("Applications/Foo 2.app", bundleID: "com.example.foo")
        let other = try fixture.addBundle("Applications/Foo.app", bundleID: "com.example.foo")
        let trashed = try fixture.addBundle(".Trash/Foo.app", bundleID: "com.example.foo")
        let deleted = fixture.root.appendingPathComponent("Downloads/Foo.app", isDirectory: true)
        let manager = fixture.manager(registeredURLs: [other, scanned, trashed, deleted, other])

        #expect(manager.otherCopyURLs(of: Self.app("Foo", "com.example.foo", at: scanned))
            == [other.resolvingSymlinksInPath()])
        #expect(fixture.manager(registeredURLs: [scanned])
            .otherCopyURLs(of: Self.app("Foo", "com.example.foo", at: scanned)).isEmpty)
    }

    @Test
    func protectsSystemAppsIncludingSymlinksIntoSystemLocations() throws {
        let fixture = try BundleFixture()
        defer { fixture.remove() }
        // Like /Applications/Safari.app, which links into /System/Cryptexes.
        let link = fixture.root.appendingPathComponent("Safari.app", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: link,
            withDestinationURL: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        )
        let recorder = TrashRecorder()
        let manager = fixture.manager(registeredURLs: [], recorder: recorder)

        for url in [link, URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")] {
            let app = Self.app("System", "com.example.system", at: url)
            #expect(manager.uninstallURL(for: app) == nil)
            #expect(throws: ApplicationManagerError.self) { try manager.uninstall(app) }
        }
        #expect(recorder.trashed.isEmpty)
    }

    @Test
    func protectsTheRunningAppAndEveryOtherCopyOfIt() throws {
        let fixture = try BundleFixture()
        defer { fixture.remove() }
        let running = try fixture.addBundle("Running/OpenLaunchPad.app", bundleID: "com.openlaunchpad")
        let otherCopy = try fixture.addBundle("Installed/OpenLaunchPad.app", bundleID: "com.openlaunchpad")
        let regular = try fixture.addBundle("Apps/Foo.app", bundleID: "com.example.foo")
        let manager = fixture.manager(
            registeredURLs: [],
            currentAppURL: running,
            currentBundleID: "com.openlaunchpad"
        )

        #expect(manager.uninstallURL(for: Self.app("Self", "com.example.renamed", at: running)) == nil)
        #expect(manager.uninstallURL(for: Self.app("Copy", "com.openlaunchpad", at: otherCopy)) == nil)
        #expect(manager.uninstallURL(for: Self.app("Foo", "com.example.foo", at: regular))
            == regular.resolvingSymlinksInPath())
    }

    @Test
    func uninstallingASymlinkedAppTrashesTheBundleItPointsTo() throws {
        let fixture = try BundleFixture()
        defer { fixture.remove() }
        let real = try fixture.addBundle("Shared/Client.app", bundleID: "com.example.client")
        let link = fixture.root.appendingPathComponent("Client.app", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        let recorder = TrashRecorder()
        let manager = fixture.manager(registeredURLs: [], recorder: recorder)

        try manager.uninstall(Self.app("Client", "com.example.client", at: link))

        #expect(recorder.trashed == [real.resolvingSymlinksInPath()])
    }

    private static func app(_ title: String, _ bundleID: String, at url: URL?) -> AppItem {
        AppItem(id: UUID(), bundleID: bundleID, title: title, bundleURL: url)
    }
}

private final class TrashRecorder {
    var trashed: [URL] = []
}

private final class BundleFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenLaunchPadApplicationManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func addBundle(_ relativePath: String, bundleID: String) throws -> URL {
        let bundle = root.appendingPathComponent(relativePath, isDirectory: true)
        let contents = bundle.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": bundleID, "CFBundlePackageType": "APPL"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return bundle
    }

    /// Never touches the real Trash or LaunchServices: both are replaced with fakes, and the
    /// first registered copy stands in for LaunchServices' preferred one.
    @MainActor
    func manager(
        registeredURLs: [URL],
        recorder: TrashRecorder = TrashRecorder(),
        currentAppURL: URL? = nil,
        currentBundleID: String? = "com.openlaunchpad"
    ) -> SystemApplicationManager {
        SystemApplicationManager(
            currentAppURL: currentAppURL ?? root.appendingPathComponent("NotInstalled/OpenLaunchPad.app"),
            currentBundleID: currentBundleID,
            registeredURLs: { _ in registeredURLs },
            preferredURL: { _ in registeredURLs.first },
            moveToTrash: { recorder.trashed.append($0) }
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
