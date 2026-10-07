import AppKit
import SwiftUI
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum VisibleSurface {
        case none
        case fullScreen
        case popup
    }

    enum LauncherExit {
        /// Escape, a background click, a toggle, or another app or window taking over.
        case close
        /// An app is opening.
        case launch
    }

    // Shared ViewModel and config — single instances for the whole app lifetime
    let config = ConfigStore.shared
    let viewModel: LaunchpadViewModel
    private let wallpaperProvider = WallpaperProvider()

    private let fullScreenWindow = FullScreenWindow()
    /// The insets the full-screen content was last given, for the screen the window covers.
    private var fullScreenInsets = EdgeInsets()
    /// Type-erased so new insets can replace the root; it always wraps the same view, which keeps its state.
    private lazy var fullScreenHost = NSHostingView(rootView: AnyView(fullScreenRoot(contentInsets: fullScreenInsets)))
    private lazy var popupPanel = PopupPanel(width: config.paneWidth, height: config.paneHeight)
    private lazy var settingsWindowController = SettingsWindowController(
        viewModel: viewModel,
        config: config
    )
    private var statusItem: NSStatusItem?
    private var hotkeyRef: EventHotKeyRef?
    private var hotkeyHandler: EventHandlerRef?
    private var popupDismissMonitor: Any?
    private lazy var databaseWatcher = LaunchpadDatabaseWatcher { [weak self] in
        Task { @MainActor [weak self] in
            await self?.viewModel.load()
        }
    }
    private lazy var applicationsWatcher = ApplicationsFolderWatcher { [weak self] in
        Task { @MainActor [weak self] in
            await self?.viewModel.load()
        }
    }
    private var localeObserver: NSObjectProtocol?
    private var screenParametersObserver: NSObjectProtocol?
    private var activeSpaceObserver: NSObjectProtocol?
    /// Set while full screen auto-hides the Dock and menu bar, to restore on hide.
    private var presentationOptionsBeforeFullScreen: NSApplication.PresentationOptions?

    private var visibleSurface = VisibleSurface.none
    private var launcherToggle = LauncherToggle()

    private var isLaunchpadVisible: Bool {
        visibleSurface != .none
    }

    override init() {
        let dataSource = CompositeDataSource(
            primary: LaunchpadDBDataSource(),
            fallback: ApplicationsFolderDataSource()
        )
        viewModel = LaunchpadViewModel(
            dataSource: dataSource,
            layoutStore: JSONLayoutStore(),
            iconProvider: BundleIconProvider(),
            appUsageStore: UserDefaultsAppUsageStore(),
            pageCapacity: ConfigStore.shared.pageCapacity
        )
        super.init()
    }

    // MARK: - App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        config.onGlobalShortcutChange = { [weak self] in
            self?.reregisterHotkey()
        }
        config.onMenuBarVisibilityChange = { [weak self] in
            self?.updateStatusItemVisibility()
        }
        config.onPageCapacityChange = { [weak self] in
            guard let self else { return }
            viewModel.pageCapacity = config.pageCapacity
        }
        config.onWallpaperSettingsChange = { [weak self] in
            // A dragged slider changes in steps; render once it settles.
            self?.refreshWallpaper(delay: .milliseconds(300))
        }
        registerHotkey()
        updateStatusItemVisibility()
        installLauncherSurfaces()
        refreshWallpaper()
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refitFullScreen()
                self?.refreshWallpaper()
            }
        }
        // Each Space can have its own wallpaper.
        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshWallpaper()
            }
        }
        databaseWatcher.start()
        applicationsWatcher.start()
        // App and folder names are localized and sorted for the current locale.
        localeObserver = NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.viewModel.load()
            }
        }
        Task {
            await viewModel.load()
            prewarmLauncherSurfaces()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        removePopupDismissMonitor()
        databaseWatcher.stop()
        applicationsWatcher.stop()
        if let localeObserver {
            NotificationCenter.default.removeObserver(localeObserver)
        }
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
        }
        if let activeSpaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeSpaceObserver)
        }
        unregisterHotkey()
        config.onGlobalShortcutChange = nil
        config.onMenuBarVisibilityChange = nil
        config.onPageCapacityChange = nil
        config.onWallpaperSettingsChange = nil
    }

    func applicationDidResignActive(_ notification: Notification) {
        if visibleSurface == .fullScreen {
            launcherToggle.recordImplicitDismissal()
            hideLaunchpad()
        }
    }

    // Dock icon click: reopen → show Launchpad (ADR, dock-click behavior)
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When this click's mouse-down already closed the launcher, the click still closes it, and
        // dismissing hands back the activation the Dock gave the app.
        if launcherToggle.clickCloses(launcherIsVisible: isLaunchpadVisible) {
            dismissLaunchpad()
        } else {
            showLaunchpad(popupAnchor: NSEvent.mouseLocation)
        }
        return false
    }

    // MARK: - Show / hide

    func toggleLaunchpad() {
        if isLaunchpadVisible {
            dismissLaunchpad()
        } else {
            showLaunchpad()
        }
    }

    func showLaunchpad(popupAnchor: NSPoint? = nil) {
        guard !isLaunchpadVisible else { return }

        switch config.dockClickMode {
        case .fullScreen:
            showFullScreen()
        case .popup:
            showPopup(anchorPoint: popupAnchor)
        }
    }

    /// The launcher counts as closed at once, so a click or the hotkey during the fade opens it
    /// again, which turns the fade back. What it shows is reset only once it has faded out.
    func hideLaunchpad(_ exit: LauncherExit = .close) {
        visibleSurface = .none
        removePopupDismissMonitor()
        if let options = presentationOptionsBeforeFullScreen {
            NSApp.presentationOptions = options
            presentationOptionsBeforeFullScreen = nil
        }
        let presentation = viewModel.presentationID
        let endPresentation = { [weak self] in
            // A show since then keeps what it found.
            guard let self, viewModel.presentationID == presentation,
                  !fullScreenWindow.isVisible, !popupPanel.isVisible else { return }
            // At once, so a quick reopen doesn't find the folder still shrinking away.
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { self.viewModel.endPresentation() }
        }
        let motion = launcherMotion
        fullScreenWindow.hide(exit == .launch ? motion.fullScreenLaunch : motion.fullScreenClose, then: endPresentation)
        popupPanel.hide(motion.popupClose, then: endPresentation)
    }

    /// Closes the launcher without launching anything. Opening it may have activated this app
    /// (full screen, or a Dock click), which would otherwise keep the menu bar and keyboard with
    /// no window showing. Hiding the app hands activation to the app underneath, as Launchpad did,
    /// at once, while the launcher fades out above it.
    func dismissLaunchpad() {
        hideLaunchpad()
        let showsOtherWindow = NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) }
        if NSApp.isActive && !showsOtherWindow {
            fullScreenWindow.staysInFrontWhileHiding()
            NSApp.hide(nil)
        }
    }

    /// The animation settings and Reduce Motion, for the launcher windows' own transitions.
    private var launcherMotion: LaunchpadMotion {
        LaunchpadMotion(config: config, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    /// Windows of a hidden app stay off screen, so undo dismissLaunchpad's hide before showing one.
    private func unhideIfNeeded() {
        if NSApp.isHidden {
            NSApp.unhideWithoutActivation()
        }
    }

    private func stepBackOrDismiss() {
        if !viewModel.stepBack() { dismissLaunchpad() }
    }

    // MARK: - Launcher surfaces

    /// Builds each surface's content once, so a show only orders a window in and views keep their
    /// state between shows. `LaunchpadViewModel.presentationID` tells them a new show began.
    private func installLauncherSurfaces() {
        // Each window sets its own size, so the content needn't be measured for size constraints.
        fullScreenHost.sizingOptions = []
        let backdropHost = NSHostingView(rootView: FullScreenBackdrop()
            .launchpadMotion()
            .environment(config)
            .environment(wallpaperProvider))
        backdropHost.sizingOptions = []
        fullScreenWindow.setContent(backdrop: backdropHost, content: fullScreenHost)
        fullScreenWindow.onCancel = { [weak self] in self?.stepBackOrDismiss() }
        refitFullScreen()

        let popupHost = NSHostingController(rootView: MenuBarPanelView(onDismissRequested: { [weak self] in
            self?.dismissLaunchpad()
        }, onAppLaunched: { [weak self] in
            self?.hideLaunchpad(.launch)
        }, onOpenSettings: { [weak self] in
            self?.openSettings()
        })
            .launchpadMotion()
            .environment(viewModel)
            .environment(config))
        popupHost.sizingOptions = []
        popupPanel.setContent(popupHost)
        popupPanel.onCancel = { [weak self] in self?.stepBackOrDismiss() }
        popupPanel.onResignKey = { [weak self] in self?.popupDidResignKey() }
        popupPanel.fit(to: popupSize)
    }

    /// Lays out and draws both surfaces while they are ordered out, once the apps have loaded, so
    /// the first show has nothing left to build.
    private func prewarmLauncherSurfaces() {
        popupPanel.appearance = config.popupAppearance.nsAppearance
        for window: NSWindow in [fullScreenWindow, popupPanel] {
            window.contentView?.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
        }
    }

    private var popupSize: NSSize {
        NSSize(width: config.paneWidth, height: config.paneHeight)
    }

    // MARK: - Full-screen mode

    private func fullScreenRoot(contentInsets: EdgeInsets) -> some View {
        LaunchpadView(
            contentInsets: contentInsets,
            onDismiss: dismissLaunchpad,
            onAppLaunched: { [weak self] in self?.hideLaunchpad(.launch) },
            onOpenSettings: openSettings
        )
            .launchpadMotion()
            .environment(viewModel)
            .environment(config)
    }

    /// Renders the wallpaper of the screen full screen opens on, when it changed, so a show finds
    /// it ready. Each show calls this too, and keeps the previous render up until a new one arrives.
    private func refreshWallpaper(delay: Duration = .zero) {
        guard config.backgroundStyle == .wallpaper, let screen = NSScreen.main else { return }
        wallpaperProvider.refresh(for: WallpaperScreen(screen), blurRadius: config.backgroundBlurRadius, delay: delay)
    }

    /// Fits the window and its content insets to the screen full screen opens on, reapplying each
    /// only when it changed.
    private func refitFullScreen() {
        guard let screen = NSScreen.main else { return }
        fullScreenWindow.fit(to: screen)
        let insets = FullScreenWindow.contentInsets(
            for: screen,
            autoHidesDockAndMenuBar: config.autoHidesDockAndMenuBar
        )
        if insets != fullScreenInsets {
            fullScreenInsets = insets
            fullScreenHost.rootView = AnyView(fullScreenRoot(contentInsets: insets))
        }
    }

    private func showFullScreen() {
        let signpost = LauncherShowSignpost("Full screen")
        defer { signpost.end() }
        visibleSurface = .fullScreen
        if config.autoHidesDockAndMenuBar {
            presentationOptionsBeforeFullScreen = NSApp.presentationOptions
            // Takes effect while this app is active. Auto-hiding the menu bar requires a Dock
            // option, and an invalid combination raises.
            NSApp.presentationOptions = [.autoHideDock, .autoHideMenuBar]
        }
        unhideIfNeeded()
        refitFullScreen()
        refreshWallpaper()
        viewModel.beginPresentation()
        fullScreenWindow.show(launcherMotion.fullScreenShow)
    }

    // MARK: - Popup mode

    func showPopup(anchorPoint: NSPoint?) {
        let signpost = LauncherShowSignpost("Popup")
        defer { signpost.end() }
        popupPanel.appearance = config.popupAppearance.nsAppearance
        popupPanel.fit(to: popupSize)
        unhideIfNeeded()
        viewModel.beginPresentation()
        popupPanel.show(anchorPoint: anchorPoint, transition: launcherMotion.popupShow)
        visibleSurface = .popup
        installPopupDismissMonitor()
    }

    // MARK: - Menu bar

    private func updateStatusItemVisibility() {
        if config.showMenuBarIcon {
            installStatusItemIfNeeded()
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else {
            NSStatusBar.system.removeStatusItem(item)
            return
        }

        let image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "OpenLaunchPad")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "OpenLaunchPad"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            hideLaunchpad()
            showStatusMenu(relativeTo: sender)
            return
        }

        if launcherToggle.clickCloses(launcherIsVisible: isLaunchpadVisible) {
            dismissLaunchpad()
        } else {
            let anchorPoint = statusItemAnchor(for: sender)
            DispatchQueue.main.async { [weak self] in
                self?.showPopup(anchorPoint: anchorPoint)
            }
        }
    }

    /// Closes the popup when focus moves to another window or app. The outside-click monitor
    /// stays as a fallback.
    private func popupDidResignKey() {
        // A click on the status item toggles the popup itself.
        if let statusWindow = statusItem?.button?.window, NSApp.currentEvent?.window === statusWindow {
            return
        }
        // Wait a turn: a sheet, such as the uninstall confirmation, takes key from the panel
        // while it attaches, and the popup must stay open under it.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.visibleSurface == .popup,
                  !self.popupPanel.isKeyWindow, self.popupPanel.attachedSheet == nil else { return }
            self.launcherToggle.recordImplicitDismissal()
            self.dismissLaunchpad()
        }
    }

    private func installPopupDismissMonitor() {
        removePopupDismissMonitor()
        popupDismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.visibleSurface == .popup else { return }
                self.launcherToggle.recordImplicitDismissal()
                self.dismissLaunchpad()
            }
        }
    }

    private func removePopupDismissMonitor() {
        if let popupDismissMonitor {
            NSEvent.removeMonitor(popupDismissMonitor)
            self.popupDismissMonitor = nil
        }
    }

    private func showStatusMenu(relativeTo button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(withTitle: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")

        menu.addItem(.separator())
        menu.addItem(withTitle: "About OpenLaunchPad", action: #selector(showAboutPanel), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit OpenLaunchPad", action: #selector(quitApplication), keyEquivalent: "q")

        menu.items.forEach { item in
            item.target = self
            item.submenu?.items.forEach { $0.target = self }
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }

    private func statusItemAnchor(for button: NSStatusBarButton) -> NSPoint {
        guard let window = button.window else { return NSEvent.mouseLocation }
        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = window.convertToScreen(buttonRect)
        return NSPoint(x: screenRect.midX, y: screenRect.minY)
    }

    func openSettings() {
        hideLaunchpad()
        unhideIfNeeded()
        settingsWindowController.present()
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    @objc private func showAboutPanel() {
        unhideIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    // MARK: - Global hotkey (Carbon, ADR-5)

    private func registerHotkey() {
        guard let combo = config.globalShortcut else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let ptr = userData else { return OSStatus(eventNotHandledErr) }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(ptr).takeUnretainedValue()
                LauncherShowSignpost.hotkeyPressed()
                Task { @MainActor in delegate.toggleLaunchpad() }
                return noErr
            },
            1, &eventType, selfPtr, &hotkeyHandler
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x4F4C_5044), id: 1)  // "OLPD"
        RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotkeyRef)
    }

    private func unregisterHotkey() {
        if let ref = hotkeyRef { UnregisterEventHotKey(ref); hotkeyRef = nil }
        if let handler = hotkeyHandler { RemoveEventHandler(handler); hotkeyHandler = nil }
    }

    /// Call when the user changes the shortcut in Settings.
    func reregisterHotkey() {
        unregisterHotkey()
        registerHotkey()
    }
}
