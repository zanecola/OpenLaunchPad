import Foundation

/// A file the wallpaper can be drawn from. Its modification date is part of the cache key, so a
/// picture replaced in place renders again.
struct WallpaperSource: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case image
        /// An Aerial's video, drawn from its first frame.
        case video
    }

    let kind: Kind
    let url: URL
    let modificationDate: Date
}

/// Finds the files behind a screen's desktop picture.
///
/// `NSWorkspace.desktopImageURL(for:)` names the picture, except while an Aerial is the
/// wallpaper: it then reports a placeholder, and the Aerial is looked up in the wallpaper store
/// and the idle-assets folder. Those are undocumented, so every read is defensive, and anything
/// unexpected yields no source rather than an error.
struct WallpaperSourceResolver: Sendable {
    static let aerialsProvider = "com.apple.wallpaper.choice.aerials"

    /// What `desktopImageURL(for:)` reports while an Aerial is the wallpaper.
    var aerialPlaceholder = URL(fileURLWithPath: "/System/Library/CoreServices/DefaultDesktop.heic")
    var storeIndex = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
    var aerialAssets = URL(fileURLWithPath: "/Library/Application Support/com.apple.idleassetsd")

    /// The files to try, in order; empty when there is nothing to draw.
    func sources(desktopImageURL: URL?, displayUUID: String?) -> [WallpaperSource] {
        // The reported URL follows the current Space, so any other picture wins over the store.
        // The placeholder can also be a chosen picture, so then the store decides.
        if desktopImageURL == nil || desktopImageURL?.path == aerialPlaceholder.path,
           let assetID = aerialAssetID(displayUUID: displayUUID) {
            return aerialSources(assetID: assetID)
        }
        guard let url = desktopImageURL.flatMap(pictureFile), let source = source(.image, at: url) else { return [] }
        return [source]
    }

    // MARK: - Aerials

    /// The Aerial chosen for this display, else for all displays, else the system default. No
    /// public API names the current Space, so an Aerial chosen for a single Space is used only
    /// when those choices are not an Aerial.
    private func aerialAssetID(displayUUID: String?) -> String? {
        guard let data = try? Data(contentsOf: storeIndex),
              let index = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }

        let displays = index["Displays"] as? [String: Any]
        let sharedChoice = [displayUUID.flatMap { displays?[$0] }, index["AllSpacesAndDisplays"], index["SystemDefault"]]
            .lazy
            .compactMap(Self.desktopChoice(in:))
            .first
        if let assetID = sharedChoice.flatMap(Self.aerialAssetID(of:)) {
            return assetID
        }

        let spaces = index["Spaces"] as? [String: Any] ?? [:]
        return spaces.keys.sorted().lazy
            .compactMap { spaces[$0] as? [String: Any] }
            .flatMap { space in [displayUUID.flatMap { (space["Displays"] as? [String: Any])?[$0] }, space["Default"]] }
            .compactMap { Self.desktopChoice(in: $0).flatMap(Self.aerialAssetID(of:)) }
            .first
    }

    /// The first desktop choice of a store entry, which reads
    /// `{Desktop or Linked: {Content: {Choices: [{Provider, Configuration}]}}}`.
    private static func desktopChoice(in entry: Any?) -> [String: Any]? {
        guard let entry = entry as? [String: Any],
              let desktop = (entry["Desktop"] ?? entry["Linked"]) as? [String: Any],
              let content = desktop["Content"] as? [String: Any],
              let choices = content["Choices"] as? [[String: Any]]
        else { return nil }
        return choices.first
    }

    /// An Aerial choice's Configuration is a property list holding its asset ID.
    private static func aerialAssetID(of choice: [String: Any]) -> String? {
        guard choice["Provider"] as? String == aerialsProvider,
              let configuration = choice["Configuration"] as? Data,
              let decoded = try? PropertyListSerialization.propertyList(from: configuration, format: nil) as? [String: Any],
              let assetID = decoded["assetID"] as? String,
              // It names files, so it must be a plain file name.
              !assetID.isEmpty, !assetID.contains("/"), !assetID.hasPrefix(".")
        else { return nil }
        return assetID
    }

    /// The video, then its small preview image.
    private func aerialSources(assetID: String) -> [WallpaperSource] {
        let customer = aerialAssets.appendingPathComponent("Customer")
        // One folder per format, such as 4KSDR240FPS; the video is in whichever was downloaded.
        let formats = (try? FileManager.default.contentsOfDirectory(atPath: customer.path)) ?? []
        let video = formats.sorted().lazy
            .compactMap { source(.video, at: customer.appendingPathComponent("\($0)/\(assetID).mov")) }
            .first
        let preview = source(.image, at: aerialAssets.appendingPathComponent("snapshots/asset-preview-\(assetID).jpg"))
        return [video, preview].compactMap { $0 }
    }

    // MARK: - Files

    /// A built-in dynamic wallpaper is a `.madesktop` property list whose picture downloads on
    /// demand; the thumbnail it names stands in for it.
    private func pictureFile(for url: URL) -> URL? {
        guard url.pathExtension == "madesktop" else { return url }
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let thumbnail = plist["thumbnailPath"] as? String
        else { return nil }
        return URL(fileURLWithPath: thumbnail)
    }

    private func source(_ kind: WallpaperSource.Kind, at url: URL) -> WallpaperSource? {
        guard let values = try? url.resolvingSymlinksInPath()
                .resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
              values.isRegularFile == true,
              let modified = values.contentModificationDate
        else { return nil }
        return WallpaperSource(kind: kind, url: url, modificationDate: modified)
    }
}
