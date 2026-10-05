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
            itemsPerPage: 35
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
            searchPaths: [fixture.firstRoot.path, fixture.secondRoot.path]
        ).loadPages().flatMap { $0 }

        // The first search path wins a duplicate bundle ID, and the item keeps that copy's path.
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

        let items = try ApplicationsFolderDataSource(searchPaths: [fixture.firstRoot.path])
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

    func addApp(name: String, bundleName: String? = nil, bundleID: String, under directory: URL) throws {
        let contents = directory
            .appendingPathComponent("\(name).app", isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleName": bundleName ?? name,
            "CFBundlePackageType": "APPL"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
