import Foundation
import Testing
@testable import OpenLaunchPad

struct ApplicationsFolderDataSourceTests {
    @Test
    func fallbackBuildsFoldersDeduplicatesAppsAndKeepsStableIDs() throws {
        let fixture = try ApplicationsFixture()
        defer { fixture.remove() }
        try fixture.addApp(name: "Mail", bundleID: "com.example.mail", under: fixture.firstRoot)
        try fixture.addApp(name: "Mail Copy", bundleID: "com.example.mail", under: fixture.secondRoot)
        let utilities = fixture.firstRoot.appendingPathComponent("Utilities", isDirectory: true)
        try fixture.addApp(name: "Terminal", bundleID: "com.example.terminal", under: utilities)
        try fixture.addApp(name: "Console", bundleID: "com.example.console", under: utilities)

        let source = ApplicationsFolderDataSource(
            searchPaths: [fixture.firstRoot.path, fixture.secondRoot.path],
            itemsPerPage: 35,
            preferredURL: { _ in nil }
        )
        let firstLoad = try source.loadPages().flatMap { $0 }
        let secondLoad = try source.loadPages().flatMap { $0 }

        #expect(firstLoad.count == 2)
        #expect(firstLoad.map(\.id) == secondLoad.map(\.id))
        #expect(firstLoad.filter { $0.title == "Mail" }.count == 1)

        guard let folder = firstLoad.compactMap({ item -> FolderItem? in
            guard case .folder(let folder) = item else { return nil }
            return folder
        }).first else {
            Issue.record("Expected a Utilities folder")
            return
        }
        #expect(folder.title == "Utilities")
        #expect(folder.apps.map(\.title) == ["Console", "Terminal"])
    }

    @Test
    func appsRecordTheBundleTheScanFound() throws {
        let fixture = try ApplicationsFixture()
        defer { fixture.remove() }
        try fixture.addApp(name: "Mail Copy", bundleID: "com.example.mail", under: fixture.firstRoot)
        try fixture.addApp(name: "Mail", bundleID: "com.example.mail", under: fixture.secondRoot)
        let tools = fixture.firstRoot.appendingPathComponent("Tools", isDirectory: true)
        try fixture.addApp(name: "Notes", bundleID: "com.example.notes", under: tools)
        try fixture.addApp(name: "Terminal", bundleID: "com.example.terminal", under: tools)

        let items = try ApplicationsFolderDataSource(
            searchPaths: [fixture.firstRoot.path, fixture.secondRoot.path],
            preferredURL: { _ in nil }
        ).loadPages().flatMap { $0 }

        // Without a preferred copy or versions, the first search path wins a duplicate bundle ID,
        // and the item keeps that copy's path.
        guard items.count == 2, case .app(let mail) = items[0], case .folder(let folder) = items[1] else {
            Issue.record("Expected Mail Copy and the Tools folder, got \(items.map(\.title))")
            return
        }
        #expect(mail.bundleURL?.path == fixture.firstRoot.appendingPathComponent("Mail Copy.app").path)
        #expect(folder.apps.map { $0.bundleURL?.path } == [
            tools.appendingPathComponent("Notes.app").path,
            tools.appendingPathComponent("Terminal.app").path
        ])
    }

    @Test
    func duplicateShowsTheCopyLaunchServicesPrefersWhereverTheScanFoundIt() throws {
        let fixture = try ApplicationsFixture()
        defer { fixture.remove() }
        // Byte order puts "Foo 2.app", a leftover from Finder's Keep Both, ahead of Foo.app.
        try fixture.addApp(name: "Foo 2", bundleID: "com.example.foo", version: "1", under: fixture.firstRoot)
        let tools = fixture.firstRoot.appendingPathComponent("Tools", isDirectory: true)
        try fixture.addApp(name: "Foo", bundleID: "com.example.foo", version: "2", under: tools)
        try fixture.addApp(name: "Notes", bundleID: "com.example.notes", under: tools)
        let preferred = tools.appendingPathComponent("Foo.app", isDirectory: true)

        let items = try ApplicationsFolderDataSource(
            searchPaths: [fixture.firstRoot.path],
            preferredURL: { $0 == "com.example.foo" ? preferred : nil }
        ).loadPages().flatMap { $0 }

        // The preferred copy keeps its place in its folder, and the other copy has no tile.
        guard items.count == 1, case .folder(let folder) = items[0] else {
            Issue.record("Expected only the Tools folder, got \(items.map(\.title))")
            return
        }
        #expect(folder.apps.map(\.title) == ["Foo", "Notes"])
        #expect(folder.apps[0].bundleURL?.path == preferred.path)
    }

    @Test
    func duplicateWithoutAScannedPreferredCopyShowsTheHighestVersion() throws {
        let fixture = try ApplicationsFixture()
        defer { fixture.remove() }
        try fixture.addApp(name: "Foo 2", bundleID: "com.example.foo", version: "1.9", under: fixture.firstRoot)
        try fixture.addApp(name: "Foo", bundleID: "com.example.foo", version: "1.10", under: fixture.firstRoot)
        // Say LaunchServices prefers a build outside the Applications folders.
        let elsewhere = fixture.root.appendingPathComponent("DerivedData/Foo.app", isDirectory: true)

        let items = try ApplicationsFolderDataSource(
            searchPaths: [fixture.firstRoot.path],
            preferredURL: { _ in elsewhere }
        ).loadPages().flatMap { $0 }

        guard items.count == 1, case .app(let foo) = items[0] else {
            Issue.record("Expected one Foo tile, got \(items.map(\.title))")
            return
        }
        #expect(foo.title == "Foo")
        #expect(foo.bundleVersion == "1.10")
    }

    @Test
    func titlesUseTheFinderNameWhileIDsFollowTheBundleID() throws {
        let fixture = try ApplicationsFixture()
        defer { fixture.remove() }
        try fixture.addApp(
            name: "Visual Studio Code",
            bundleName: "Code",
            bundleID: "com.example.code",
            under: fixture.firstRoot
        )
        let source = ApplicationsFolderDataSource(searchPaths: [fixture.firstRoot.path])

        let first = try #require(source.loadPages().flatMap { $0 }.first)
        guard case .app(let app) = first else {
            Issue.record("Expected a top-level app")
            return
        }
        #expect(app.title == "Visual Studio Code")
        #expect(app.aliases == ["Code"])

        try FileManager.default.moveItem(
            at: fixture.firstRoot.appendingPathComponent("Visual Studio Code.app"),
            to: fixture.firstRoot.appendingPathComponent("VS Code.app")
        )
        let renamed = try #require(source.loadPages().flatMap { $0 }.first)
        #expect(renamed.title == "VS Code")
        #expect(renamed.id == app.id)
    }

    @Test
    func inPlaceUpdateChangesTheScannedItemButNotItsID() throws {
        let fixture = try ApplicationsFixture()
        defer { fixture.remove() }
        try fixture.addApp(name: "Mail", bundleID: "com.example.mail", version: "1", under: fixture.firstRoot)
        let source = ApplicationsFolderDataSource(searchPaths: [fixture.firstRoot.path])
        let before = try source.loadPages()

        try fixture.addApp(name: "Mail", bundleID: "com.example.mail", version: "2", under: fixture.firstRoot)
        let after = try source.loadPages()

        #expect(after.flatMap { $0 }.map(\.id) == before.flatMap { $0 }.map(\.id))
        #expect(after != before)
    }

    @Test
    func localizedDirectoryIsTitledWithoutItsSuffix() throws {
        let fixture = try ApplicationsFixture()
        defer { fixture.remove() }
        let webApps = fixture.firstRoot.appendingPathComponent("Chrome Apps.localized", isDirectory: true)
        try fixture.addApp(name: "Docs", bundleID: "com.example.docs", under: webApps)
        try fixture.addApp(name: "Sheets", bundleID: "com.example.sheets", under: webApps)

        let items = try ApplicationsFolderDataSource(searchPaths: [fixture.firstRoot.path])
            .loadPages().flatMap { $0 }

        #expect(items.map(\.title) == ["Chrome Apps"])
    }

    @Test
    func directoryWithOneAppShowsTheAppAtTopLevel() throws {
        let fixture = try ApplicationsFixture()
        defer { fixture.remove() }
        try fixture.addApp(name: "Mail", bundleID: "com.example.mail", under: fixture.firstRoot)
        let vendor = fixture.firstRoot.appendingPathComponent("Vendor", isDirectory: true)
        try fixture.addApp(name: "Reader", bundleID: "com.example.reader", under: vendor)
        // Its second app is a duplicate, so this directory is left with one app too.
        let tools = fixture.firstRoot.appendingPathComponent("Tools", isDirectory: true)
        try fixture.addApp(name: "Mail Copy", bundleID: "com.example.mail", under: tools)
        try fixture.addApp(name: "Notes", bundleID: "com.example.notes", under: tools)

        let items = try ApplicationsFolderDataSource(searchPaths: [fixture.firstRoot.path], preferredURL: { _ in nil })
            .loadPages().flatMap { $0 }

        #expect(items.map(\.title) == ["Mail", "Notes", "Reader"])
        #expect(items.allSatisfy { if case .app = $0 { true } else { false } })
    }

    @Test
    func itemsFromAllSearchPathsAreSortedByDisplayedName() throws {
        let fixture = try ApplicationsFixture()
        defer { fixture.remove() }
        for (name, id) in [("Xcode", "xcode"), ("iMovie", "imovie"), ("zoom.us", "zoom"), ("App 10", "app10")] {
            try fixture.addApp(name: name, bundleID: "com.example.\(id)", under: fixture.firstRoot)
        }
        let tools = fixture.firstRoot.appendingPathComponent("Tools", isDirectory: true)
        try fixture.addApp(name: "Terminal", bundleID: "com.example.terminal", under: tools)
        try fixture.addApp(name: "console", bundleID: "com.example.console", under: tools)
        try fixture.addApp(name: "Calendar", bundleID: "com.example.calendar", under: fixture.secondRoot)
        try fixture.addApp(name: "App 2", bundleID: "com.example.app2", under: fixture.secondRoot)

        let items = try ApplicationsFolderDataSource(
            searchPaths: [fixture.firstRoot.path, fixture.secondRoot.path]
        ).loadPages().flatMap { $0 }

        #expect(items.map(\.title) == ["App 2", "App 10", "Calendar", "iMovie", "Tools", "Xcode", "zoom.us"])
        guard case .folder(let folder) = items[4] else {
            Issue.record("Expected the Tools folder")
            return
        }
        #expect(folder.apps.map(\.title) == ["console", "Terminal"])
    }

    @Test
    func appScannedMidInstallAppearsOnceItsInfoPlistIsWritten() throws {
        let fixture = try ApplicationsFixture()
        defer { fixture.remove() }
        let contents = fixture.firstRoot.appendingPathComponent("Half.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let source = ApplicationsFolderDataSource(searchPaths: [fixture.firstRoot.path])

        #expect(try source.loadPages().flatMap { $0 }.isEmpty)

        try fixture.addApp(name: "Half", bundleID: "com.example.half", under: fixture.firstRoot)

        #expect(try source.loadPages().flatMap { $0 }.map(\.title) == ["Half"])
    }
}

private final class ApplicationsFixture {
    let root: URL
    let firstRoot: URL
    let secondRoot: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenLaunchPadApplicationsTests-\(UUID().uuidString)", isDirectory: true)
        firstRoot = root.appendingPathComponent("Applications", isDirectory: true)
        secondRoot = root.appendingPathComponent("SystemApplications", isDirectory: true)
        try FileManager.default.createDirectory(at: firstRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondRoot, withIntermediateDirectories: true)
    }

    func addApp(
        name: String,
        bundleName: String? = nil,
        bundleID: String,
        version: String? = nil,
        under directory: URL
    ) throws {
        let contents = directory
            .appendingPathComponent("\(name).app", isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        var plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleName": bundleName ?? name,
            "CFBundlePackageType": "APPL"
        ]
        plist["CFBundleVersion"] = version
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
