import AppKit
import SwiftUI
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // Shared ViewModel and config — single instances for the whole app lifetime
    let config = ConfigStore.shared
    let viewModel: LaunchpadViewModel

    private let fullScreenWindow = FullScreenWindow()
    private var popupPanel: PopupPanel?
    private var hotkeyRef: EventHotKeyRef?
    private var hotkeyHandler: EventHandlerRef?
    private lazy var databaseWatcher = LaunchpadDatabaseWatcher { [weak self] in
        Task { @MainActor [weak self] in
            await self?.viewModel.load()
        }
    }

    private var isLaunchpadVisible = false

    override init() {
        let dataSource = CompositeDataSource(
            primary: LaunchpadDBDataSource(),
            fallback: ApplicationsFolderDataSource()
        )
        viewModel = LaunchpadViewModel(
            dataSource: dataSource,
            layoutStore: JSONLayoutStore(),
            iconProvider: BundleIconProvider()
        )
        super.init()
    }

    // MARK: - App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        config.onGlobalShortcutChange = { [weak self] in
            self?.reregisterHotkey()
        }
        registerHotkey()
        databaseWatcher.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        databaseWatcher.stop()
        unregisterHotkey()
        config.onGlobalShortcutChange = nil
    }

    func applicationDidResignActive(_ notification: Notification) {
        if isLaunchpadVisible {
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
        isLaunchpadVisible = true

        switch config.dockClickMode {
        case .fullScreen:
            showFullScreen()
        case .popup:
            showPopup(anchorPoint: popupAnchor)
        }
    }

    func hideLaunchpad() {
        isLaunchpadVisible = false
        fullScreenWindow.hide()
        popupPanel?.hide()
        viewModel.searchQuery = ""
        viewModel.expandedFolderID = nil
    }

    // MARK: - Full-screen mode

    private func showFullScreen() {
        let root = LaunchpadView(onDismiss: hideLaunchpad)
            .environment(viewModel)
            .environment(config)

        let controller = NSHostingController(rootView: root)
        fullScreenWindow.show(hostingView: controller)
    }

    // MARK: - Dock popup mode

    func showPopup(anchorPoint: NSPoint?) {
        let panel = popupPanel ?? PopupPanel(width: config.paneWidth, height: config.paneHeight)
        popupPanel = panel

        let root = MenuBarPanelView(onDismissRequested: { [weak self] in
            self?.hideLaunchpad()
        })
            .environment(viewModel)
            .environment(config)

        let controller = NSHostingController(rootView: root)
        panel.show(
            anchorPoint: anchorPoint,
            hostingView: controller,
            width: config.paneWidth,
            height: config.paneHeight
        )
        isLaunchpadVisible = true
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
