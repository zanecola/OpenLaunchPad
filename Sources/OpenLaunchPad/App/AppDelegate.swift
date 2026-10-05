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

    // Shared ViewModel and config — single instances for the whole app lifetime
    let config = ConfigStore.shared
    let viewModel: LaunchpadViewModel

    private let fullScreenWindow = FullScreenWindow()
    private lazy var settingsWindowController = SettingsWindowController(
        viewModel: viewModel,
        config: config
    )
    private var popupPanel: PopupPanel?
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

    private var visibleSurface = VisibleSurface.none

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
            appUsageStore: UserDefaultsAppUsageStore()
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
        registerHotkey()
        updateStatusItemVisibility()
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
        Task { await viewModel.load() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        removePopupDismissMonitor()
        databaseWatcher.stop()
        applicationsWatcher.stop()
        if let localeObserver {
            NotificationCenter.default.removeObserver(localeObserver)
        }
        unregisterHotkey()
        config.onGlobalShortcutChange = nil
        config.onMenuBarVisibilityChange = nil
    }

    func applicationDidResignActive(_ notification: Notification) {
        if visibleSurface == .fullScreen {
            hideLaunchpad()
        }
    }

    // Dock icon click: reopen → show Launchpad (ADR, dock-click behavior)
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if isLaunchpadVisible {
            hideLaunchpad()
        } else {
            showLaunchpad(popupAnchor: NSEvent.mouseLocation)
        }
        return false
    }

    // MARK: - Show / hide

    func toggleLaunchpad() {
        if isLaunchpadVisible {
            hideLaunchpad()
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

    func hideLaunchpad() {
        visibleSurface = .none
        removePopupDismissMonitor()
        fullScreenWindow.hide()
        popupPanel?.hide()
        viewModel.searchQuery = ""
        viewModel.expandedFolderID = nil
    }

    private func stepBackOrHide() {
        if !viewModel.stepBack() { hideLaunchpad() }
    }

    // MARK: - Full-screen mode

    private func showFullScreen() {
        let root = LaunchpadView(
            onDismiss: hideLaunchpad,
            onOpenSettings: openSettings
        )
            .environment(viewModel)
            .environment(config)

        let controller = NSHostingController(rootView: root)
        visibleSurface = .fullScreen
        fullScreenWindow.onCancel = { [weak self] in self?.stepBackOrHide() }
        fullScreenWindow.show(hostingView: controller)
    }

    // MARK: - Popup mode

    func showPopup(anchorPoint: NSPoint?) {
        let panel = popupPanel ?? PopupPanel(width: config.paneWidth, height: config.paneHeight)
        popupPanel = panel

        let root = MenuBarPanelView(onDismissRequested: { [weak self] in
            self?.hideLaunchpad()
        }, onOpenSettings: { [weak self] in
            self?.openSettings()
        })
            .environment(viewModel)
            .environment(config)

        let controller = NSHostingController(rootView: root)
        panel.onCancel = { [weak self] in self?.stepBackOrHide() }
        panel.show(
            anchorPoint: anchorPoint,
            hostingView: controller,
            width: config.paneWidth,
            height: config.paneHeight
        )
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

        if isLaunchpadVisible {
            hideLaunchpad()
        } else {
            let anchorPoint = statusItemAnchor(for: sender)
            DispatchQueue.main.async { [weak self] in
                self?.showPopup(anchorPoint: anchorPoint)
            }
        }
    }

    private func installPopupDismissMonitor() {
        removePopupDismissMonitor()
        popupDismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.visibleSurface == .popup else { return }
                self?.hideLaunchpad()
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
        settingsWindowController.present()
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    @objc private func showAboutPanel() {
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
