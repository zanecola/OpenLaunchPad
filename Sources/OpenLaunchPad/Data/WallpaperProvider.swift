import AppKit
import AVFoundation
import CoreImage
import ImageIO
import Observation

/// The blurred desktop picture full screen draws in Wallpaper mode.
struct BackdropWallpaper: Equatable {
    /// New for every render, so the view can fade a new image in.
    let id: Int
    let image: CGImage

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

/// The screen a wallpaper is rendered for.
struct WallpaperScreen {
    /// The display's UUID, which also keys a per-display choice in the wallpaper store.
    let id: String
    /// In points.
    let size: CGSize
    let desktopImageURL: URL?
}

extension WallpaperScreen {
    @MainActor
    init(_ screen: NSScreen) {
        self.init(
            id: Self.id(of: screen),
            size: screen.frame.size,
            desktopImageURL: NSWorkspace.shared.desktopImageURL(for: screen)
        )
    }

    /// The display's UUID, or its name when it has none.
    @MainActor
    static func id(of screen: NSScreen) -> String {
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let uuid = number.flatMap { CGDisplayCreateUUIDFromDisplayID($0.uint32Value)?.takeRetainedValue() }
        return uuid.flatMap { CFUUIDCreateString(nil, $0) as String? } ?? screen.localizedName
    }
}

/// Everything a render depends on, so an equal request reuses it.
struct WallpaperRequest: Hashable, Sendable {
    let sources: [WallpaperSource]
    let pixelWidth: Int
    let pixelHeight: Int
    /// The Gaussian blur's standard deviation, in rendered pixels.
    let blurSigma: Double

    init(sources: [WallpaperSource], screenSize: CGSize, blurRadius: Double) {
        let scale = Self.pixelsPerPoint(blurRadius: blurRadius)
        self.sources = sources
        pixelWidth = max(Int((screenSize.width * scale).rounded()), 1)
        pixelHeight = max(Int((screenSize.height * scale).rounded()), 1)
        blurSigma = blurRadius * scale
    }

    /// No sharper than the blur leaves it: about 12 rendered pixels of blur, at a quarter to one
    /// pixel per point. Below a 12 pt radius it is one pixel per point.
    static func pixelsPerPoint(blurRadius: Double) -> Double {
        blurRadius > 0 ? min(max(12 / blurRadius, 0.25), 1) : 1
    }
}

enum WallpaperRenderer {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// The first source that decodes, aspect-filled to the request's size, blurred, a little more
    /// saturated and darker, as Launchpad drew it. nil when none decodes.
    static func render(_ request: WallpaperRequest) async -> CGImage? {
        let size = CGSize(width: request.pixelWidth, height: request.pixelHeight)
        for source in request.sources {
            if let image = await decode(source, toCover: size) {
                return process(image, size: size, blurSigma: request.blurSigma)
            }
        }
        return nil
    }

    private static func decode(_ source: WallpaperSource, toCover size: CGSize) async -> CGImage? {
        // Twice the longer side still covers the screen when the picture's aspect ratio differs.
        let longestSide = 2 * max(size.width, size.height)
        switch source.kind {
        case .image:
            guard let imageSource = CGImageSourceCreateWithURL(source.url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: longestSide
            ]
            let index = CGImageSourceGetPrimaryImageIndex(imageSource)
            return CGImageSourceCreateThumbnailAtIndex(imageSource, index, options as CFDictionary)
        case .video:
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: source.url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: longestSide, height: longestSide)
            return try? await generator.image(at: .zero).image
        }
    }

    private static func process(_ image: CGImage, size: CGSize, blurSigma: Double) -> CGImage? {
        let picture = CIImage(cgImage: image)
        let scale = max(size.width / picture.extent.width, size.height / picture.extent.height)
        let scaled = picture.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let filled = scaled.transformed(by: CGAffineTransform(
            translationX: (size.width - scaled.extent.width) / 2 - scaled.extent.minX,
            y: (size.height - scaled.extent.height) / 2 - scaled.extent.minY
        ))
        // Clamped first, so the edges don't blur toward transparent.
        let clamped = filled.clampedToExtent()
        let blurred = blurSigma > 0 ? clamped.applyingGaussianBlur(sigma: blurSigma) : clamped
        let output = blurred
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.15,
                kCIInputBrightnessKey: -0.04
            ])
            .cropped(to: CGRect(origin: .zero, size: size))
        return context.createCGImage(
            output,
            from: output.extent,
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.displayP3)
        )
    }
}

/// Renders and caches the blurred wallpaper of each screen a launcher opens on. Each display keeps
/// its own status, so full screen on one display and the popup on another never show each
/// other's picture.
@MainActor
@Observable
final class WallpaperProvider {
    enum Status: Equatable {
        /// Not rendered yet; the launcher draws its base until it is.
        case pending
        case ready(BackdropWallpaper)
        /// Nothing found or nothing decoded; the launcher falls back to Glass, or Solid.
        case unavailable
    }

    /// The latest render of each display, by display UUID.
    private(set) var statuses: [String: Status] = [:]

    /// A display not rendered yet, or no display, is pending.
    func status(for screenID: String?) -> Status {
        screenID.flatMap { statuses[$0] } ?? .pending
    }

    @ObservationIgnored private let resolver: WallpaperSourceResolver
    /// What each display's status was rendered from, so showing on it again needs no render.
    @ObservationIgnored private var renderedRequests: [String: WallpaperRequest] = [:]
    @ObservationIgnored private var inFlight: [String: (request: WallpaperRequest, task: Task<Void, Never>)] = [:]
    @ObservationIgnored private var renderCount = 0

    init(resolver: WallpaperSourceResolver = WallpaperSourceResolver()) {
        self.resolver = resolver
    }

    /// Resolves the screen's wallpaper again, which takes a few file lookups, and renders it off
    /// the main thread only when something changed: the picture, its file, the screen size or the
    /// blur. Until then the screen's previous render stays up. `delay` lets a run of changes, such
    /// as a dragged slider, render once. Returns the render it started or is waiting for.
    @discardableResult
    func refresh(for screen: WallpaperScreen, blurRadius: Double, delay: Duration = .zero) -> Task<Void, Never>? {
        let screenID = screen.id
        let request = WallpaperRequest(
            sources: resolver.sources(desktopImageURL: screen.desktopImageURL, displayUUID: screenID),
            screenSize: screen.size,
            blurRadius: blurRadius
        )
        if let running = inFlight[screenID] {
            if running.request == request { return running.task }
            running.task.cancel()
            inFlight[screenID] = nil
        }

        if renderedRequests[screenID] == request { return nil }
        if request.sources.isEmpty {
            finish(screenID, request, with: nil)
            return nil
        }

        let task = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            let image = await Task.detached(priority: .utility) {
                await WallpaperRenderer.render(request)
            }.value
            guard !Task.isCancelled else { return }
            self?.finish(screenID, request, with: image)
        }
        inFlight[screenID] = (request, task)
        return task
    }

    private func finish(_ screenID: String, _ request: WallpaperRequest, with image: CGImage?) {
        let result: Status
        if let image {
            renderCount += 1
            result = .ready(BackdropWallpaper(id: renderCount, image: image))
        } else {
            result = .unavailable
        }
        renderedRequests[screenID] = request
        statuses[screenID] = result
        if inFlight[screenID]?.request == request {
            inFlight[screenID] = nil
        }
    }
}
