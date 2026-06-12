import AppKit
import SwiftUI

struct ScrollViewAppearance: NSViewRepresentable {
    var showsVerticalScroller = false
    var scrollerStyle: NSScroller.Style = .overlay

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureScrollView(containing: view)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            configureScrollView(containing: view)
        }
    }

    private func configureScrollView(containing view: NSView) {
        guard let scrollView = view.enclosingScrollView ?? view.firstSuperview(of: NSScrollView.self) else {
            return
        }

        scrollView.scrollerStyle = scrollerStyle
        scrollView.hasVerticalScroller = showsVerticalScroller
        scrollView.verticalScroller = showsVerticalScroller ? scrollView.verticalScroller : nil
        scrollView.autohidesScrollers = true
        scrollView.scrollerKnobStyle = .light
        scrollView.drawsBackground = false
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

private extension NSView {
    func firstSuperview<T: NSView>(of type: T.Type) -> T? {
        var candidate = superview
        while let current = candidate {
            if let match = current as? T {
                return match
            }
            candidate = current.superview
        }
        return nil
    }
}
