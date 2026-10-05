import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    static let paneWidth: CGFloat = 560
    /// A taller pane scrolls, so the window still fits a 13-inch display.
    static let maxPaneHeight: CGFloat = 600

    init(viewModel: LaunchpadViewModel, config: ConfigStore) {
        // Toolbar tabs, like macOS's own settings windows. The tab view controller titles the
        // window after the selected pane and resizes it to the pane's preferred size.
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        for pane in SettingsPane.allCases {
            let rootView = pane.content
                .frame(width: Self.paneWidth)
                .frame(maxHeight: Self.maxPaneHeight)
                .environment(viewModel)
                .environment(config)
            let hostingController = NSHostingController(rootView: rootView)
            hostingController.sizingOptions = .preferredContentSize
            hostingController.title = pane.title
            let item = NSTabViewItem(viewController: hostingController)
            item.label = pane.title
            item.image = NSImage(systemSymbolName: pane.systemImage, accessibilityDescription: nil)
            tabs.addTabViewItem(item)
        }

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        // The tab view controller sizes the window only once the selection changes.
        if let firstPane = tabs.tabViewItems.first?.viewController {
            window.setContentSize(firstPane.preferredContentSize)
        }
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        if !window.isVisible {
            window.center()
        }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }
}
