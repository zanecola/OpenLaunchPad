import AppKit
import SwiftUI

struct ScrollViewAppearance: NSViewRepresentable {
    var showsVerticalScroller = false

    func makeNSView(context: Context) -> ScrollViewAppearanceProbe {
        let view = ScrollViewAppearanceProbe()
        view.showsVerticalScroller = showsVerticalScroller
        return view
    }

    func updateNSView(_ view: ScrollViewAppearanceProbe, context: Context) {
        view.showsVerticalScroller = showsVerticalScroller
        view.refreshScrollViews()
    }
}

extension View {
    func launchpadScrollAppearance(showsVerticalScroller: Bool = false) -> some View {
        background {
            ScrollViewAppearance(showsVerticalScroller: showsVerticalScroller)
                .frame(width: 0, height: 0)
        }
    }
}

final class ScrollViewAppearanceProbe: NSView {
    var showsVerticalScroller = false

    private var windowUpdateObserver: NSObjectProtocol?
    private var pendingRefreshes: [DispatchWorkItem] = []

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        scheduleRefreshes()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observeWindowUpdates()
        scheduleRefreshes()
    }

    override func layout() {
        super.layout()
        refreshScrollViews()
    }

    deinit {
        pendingRefreshes.forEach { $0.cancel() }
        if let windowUpdateObserver {
            NotificationCenter.default.removeObserver(windowUpdateObserver)
        }
    }

    func refreshScrollViews() {
        guard let rootView = window?.contentView else { return }
        rootView.descendantScrollViews.forEach(configure)
    }

    private func scheduleRefreshes() {
        pendingRefreshes.forEach { $0.cancel() }
        pendingRefreshes = [0, 0.05, 0.2, 0.5].map { delay in
            let work = DispatchWorkItem { [weak self] in
                self?.refreshScrollViews()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            return work
        }
    }

    private func observeWindowUpdates() {
        if let windowUpdateObserver {
            NotificationCenter.default.removeObserver(windowUpdateObserver)
        }
        guard let window else {
            windowUpdateObserver = nil
            return
        }
        windowUpdateObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.refreshScrollViews()
        }
    }

    private func configure(_ scrollView: NSScrollView) {
        if scrollView.scrollerStyle != .overlay {
            scrollView.scrollerStyle = .overlay
        }
        if !scrollView.autohidesScrollers {
            scrollView.autohidesScrollers = true
        }
        if scrollView.hasVerticalScroller != showsVerticalScroller {
            scrollView.hasVerticalScroller = showsVerticalScroller
        }
        if scrollView.hasHorizontalScroller {
            scrollView.hasHorizontalScroller = false
        }
        if scrollView.drawsBackground {
            scrollView.drawsBackground = false
        }
        if scrollView.verticalScroller?.isHidden == showsVerticalScroller {
            scrollView.verticalScroller?.isHidden = !showsVerticalScroller
        }
        if scrollView.horizontalScroller?.isHidden == false {
            scrollView.horizontalScroller?.isHidden = true
        }
    }
}

private extension NSView {
    var descendantScrollViews: [NSScrollView] {
        var result: [NSScrollView] = []
        var remaining = subviews

        while let view = remaining.popLast() {
            if let scrollView = view as? NSScrollView {
                result.append(scrollView)
            }
            remaining.append(contentsOf: view.subviews)
        }
        return result
    }
}
