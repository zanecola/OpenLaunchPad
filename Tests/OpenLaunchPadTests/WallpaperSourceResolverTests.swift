import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import OpenLaunchPad

struct WallpaperSourceResolverTests {
    private static let assetID = "AB7FC3C3-8853-45CD-AB6E-89F0985C2922"
    private static let otherAssetID = "009BA758-7060-4479-8EE8-FB9B40C8FB97"

    @Test
    func anAerialIsDrawnFromItsVideoThenItsPreview() throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        try fixture.writeStore(["AllSpacesAndDisplays": WallpaperFixture.aerial(Self.assetID)])
        try fixture.writeFile("idleassetsd/Customer/TVIdleScreenStrings.bundle/Info.plist")
        let video = try fixture.writeFile("idleassetsd/Customer/4KSDR240FPS/\(Self.assetID).mov")
        let preview = try fixture.writeFile("idleassetsd/snapshots/asset-preview-\(Self.assetID).jpg")

        let sources = fixture.resolver.sources(desktopImageURL: fixture.placeholder, displayUUID: nil)

        #expect(sources.map(\.kind) == [.video, .image])
        #expect(sources.map(\.url) == [video, preview])
    }

    @Test
    func anAerialWithoutItsVideoUsesItsPreview() throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        try fixture.writeStore(["AllSpacesAndDisplays": WallpaperFixture.aerial(Self.assetID)])
        let preview = try fixture.writeFile("idleassetsd/snapshots/asset-preview-\(Self.assetID).jpg")

        #expect(fixture.resolver.sources(desktopImageURL: nil, displayUUID: nil).map(\.url) == [preview])
    }

    @Test
    func anAerialWithNoFilesHasNothingToDraw() throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        try fixture.writeStore(["AllSpacesAndDisplays": WallpaperFixture.aerial(Self.assetID)])

        #expect(fixture.resolver.sources(desktopImageURL: fixture.placeholder, displayUUID: nil).isEmpty)
    }

    @Test
    func aPictureReportedForTheCurrentSpaceWinsOverAnAerialElsewhere() throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        try fixture.writeStore(["AllSpacesAndDisplays": WallpaperFixture.aerial(Self.assetID)])
        try fixture.writeFile("idleassetsd/snapshots/asset-preview-\(Self.assetID).jpg")
        let picture = try fixture.writeFile("Pictures/Beach.heic")

        let sources = fixture.resolver.sources(desktopImageURL: picture, displayUUID: nil)

        #expect(sources.map(\.url) == [picture])
        #expect(sources.map(\.kind) == [.image])
    }

    @Test
    func theDefaultPictureIsDrawnWhenTheStoreHasNoAerial() throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        try fixture.writeStore(["AllSpacesAndDisplays": WallpaperFixture.picture()])

        #expect(fixture.resolver.sources(desktopImageURL: fixture.placeholder, displayUUID: nil).map(\.url) == [fixture.placeholder])
    }

    @Test
    func thisDisplaysChoiceWinsOverAllDisplays() throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        try fixture.writeStore([
            "AllSpacesAndDisplays": WallpaperFixture.aerial(Self.assetID),
            "Displays": ["DISPLAY-1": WallpaperFixture.aerial(Self.otherAssetID, key: "Desktop")]
        ])
        try fixture.writeFile("idleassetsd/snapshots/asset-preview-\(Self.assetID).jpg")
        let other = try fixture.writeFile("idleassetsd/snapshots/asset-preview-\(Self.otherAssetID).jpg")

        #expect(fixture.resolver.sources(desktopImageURL: fixture.placeholder, displayUUID: "DISPLAY-1").map(\.url) == [other])
        #expect(fixture.resolver.sources(desktopImageURL: fixture.placeholder, displayUUID: "DISPLAY-2").map(\.url) != [other])
    }

    @Test
    func theSystemDefaultIsUsedWhenNothingWasChosen() throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        try fixture.writeStore(["Displays": [:], "Spaces": [:], "SystemDefault": WallpaperFixture.aerial(Self.assetID)])
        let preview = try fixture.writeFile("idleassetsd/snapshots/asset-preview-\(Self.assetID).jpg")

        #expect(fixture.resolver.sources(desktopImageURL: fixture.placeholder, displayUUID: nil).map(\.url) == [preview])
    }

    @Test
    func anAerialChosenForASpaceIsUsedWhenTheSharedChoiceIsAPicture() throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        try fixture.writeStore([
            "AllSpacesAndDisplays": WallpaperFixture.picture(),
            "Spaces": ["SPACE-1": ["Default": WallpaperFixture.aerial(Self.assetID)]]
        ])
        let preview = try fixture.writeFile("idleassetsd/snapshots/asset-preview-\(Self.assetID).jpg")

        #expect(fixture.resolver.sources(desktopImageURL: fixture.placeholder, displayUUID: nil).map(\.url) == [preview])
    }

    @Test
    func anUnreadableStoreFallsBackToTheReportedPicture() throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        try fixture.writeFile("Store/Index.plist", contents: Data("not a property list".utf8))

        #expect(fixture.resolver.sources(desktopImageURL: fixture.placeholder, displayUUID: nil).map(\.url) == [fixture.placeholder])
    }

    @Test
    func malformedAerialChoicesAreIgnored() throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        try fixture.writeFile("idleassetsd/snapshots/asset-preview-.jpg")
        var notData = WallpaperFixture.aerial(Self.assetID)
        notData["Linked"] = ["Content": ["Choices": [["Provider": WallpaperSourceResolver.aerialsProvider, "Configuration": "x"]]]]

        for entry in [WallpaperFixture.aerial("../../Pictures/x"), WallpaperFixture.aerial(""), WallpaperFixture.aerial(nil), notData] {
            try fixture.writeStore(["AllSpacesAndDisplays": entry])

            #expect(fixture.resolver.sources(desktopImageURL: fixture.placeholder, displayUUID: nil).map(\.url) == [fixture.placeholder])
        }
    }

    @Test
    func aDynamicWallpaperIsDrawnFromItsThumbnail() throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        let thumbnail = try fixture.writeFile("Desktop Pictures/.thumbnails/Dome.heic")
        let dynamic = fixture.root.appendingPathComponent("Desktop Pictures/Dome.madesktop")
        let plist = try PropertyListSerialization.data(
            fromPropertyList: ["isDynamic": true, "thumbnailPath": thumbnail.path],
            format: .xml,
            options: 0
        )
        try plist.write(to: dynamic)
        let withoutThumbnail = try fixture.writeFile("Desktop Pictures/Peak.madesktop", contents: Data("x".utf8))

        #expect(fixture.resolver.sources(desktopImageURL: dynamic, displayUUID: nil).map(\.url) == [thumbnail])
        #expect(fixture.resolver.sources(desktopImageURL: withoutThumbnail, displayUUID: nil).isEmpty)
    }

    @Test
    func aMissingPictureOrADirectoryHasNothingToDraw() throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }

        #expect(fixture.resolver.sources(desktopImageURL: fixture.root.appendingPathComponent("Gone.heic"), displayUUID: nil).isEmpty)
        #expect(fixture.resolver.sources(desktopImageURL: fixture.root, displayUUID: nil).isEmpty)
        #expect(fixture.resolver.sources(desktopImageURL: nil, displayUUID: nil).isEmpty)
    }

    @Test
    func aSourceRecordsWhenItsFileChanged() throws {
        let fixture = try WallpaperFixture()
        defer { fixture.remove() }
        let picture = try fixture.writeFile("Pictures/Beach.heic")
        let modified = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: picture.path)

        #expect(fixture.resolver.sources(desktopImageURL: picture, displayUUID: nil).map(\.modificationDate) == [modified])
    }
}

/// Stands in for the wallpaper store, the idle-assets folder and the placeholder picture, under
/// a temporary directory, so tests never read the real ones.
final class WallpaperFixture {
    let root: URL
    let resolver: WallpaperSourceResolver
    var placeholder: URL { resolver.aerialPlaceholder }

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenLaunchPadWallpaperTests-\(UUID().uuidString)", isDirectory: true)
        resolver = WallpaperSourceResolver(
            aerialPlaceholder: root.appendingPathComponent("CoreServices/DefaultDesktop.heic"),
            storeIndex: root.appendingPathComponent("Store/Index.plist"),
            aerialAssets: root.appendingPathComponent("idleassetsd", isDirectory: true)
        )
        try writePicture("CoreServices/DefaultDesktop.heic")
    }

    @discardableResult
    func writeFile(_ path: String, contents: Data = Data("x".utf8)) throws -> URL {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url)
        return url
    }

    /// A small image that decodes: a JPEG for a .jpg, otherwise a PNG whatever the extension,
    /// since decoding goes by content and a CI machine may have no HEIC encoder.
    @discardableResult
    func writePicture(_ path: String, width: Int = 64, height: Int = 40) throws -> URL {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let type: UTType = url.pathExtension == "jpg" ? .jpeg : .png
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    func writeStore(_ index: [String: Any]) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: index, format: .binary, options: 0)
        try writeFile("Store/Index.plist", contents: data)
    }

    /// A store entry as macOS writes it: the choice under Linked when the desktop and the screen
    /// saver share it, or under Desktop.
    static func aerial(_ assetID: String?, key: String = "Linked") -> [String: Any] {
        var choice: [String: Any] = ["Provider": WallpaperSourceResolver.aerialsProvider, "Files": [Any]()]
        if let assetID {
            choice["Configuration"] = try! PropertyListSerialization.data(
                fromPropertyList: ["assetID": assetID],
                format: .binary,
                options: 0
            )
        }
        return [key: ["Content": ["Choices": [choice]]], "Type": "linked"]
    }

    static func picture() -> [String: Any] {
        let choice: [String: Any] = ["Provider": "com.apple.wallpaper.choice.image", "Files": [["relative": "file:///x.heic"]]]
        return ["Linked": ["Content": ["Choices": [choice]]], "Type": "linked"]
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
