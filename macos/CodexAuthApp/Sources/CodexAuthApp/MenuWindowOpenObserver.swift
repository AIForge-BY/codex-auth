import AppKit
import SwiftUI

struct MenuWindowOpenObserver: NSViewRepresentable {
    let onOpen: () -> Void

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onOpen = onOpen
        return view
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {
        nsView.onOpen = onOpen
    }

    final class ObserverView: NSView {
        var onOpen: (() -> Void)?
        private weak var observedWindow: NSWindow?
        private var didBecomeKeyObserver: NSObjectProtocol?

        deinit {
            removeObserver()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observe(window)
        }

        private func observe(_ window: NSWindow?) {
            guard observedWindow !== window else {
                return
            }
            removeObserver()
            observedWindow = window

            guard let window else {
                return
            }

            didBecomeKeyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.onOpen?()
            }

            if window.isKeyWindow {
                onOpen?()
            }
        }

        private func removeObserver() {
            if let didBecomeKeyObserver {
                NotificationCenter.default.removeObserver(didBecomeKeyObserver)
            }
            didBecomeKeyObserver = nil
        }
    }
}
