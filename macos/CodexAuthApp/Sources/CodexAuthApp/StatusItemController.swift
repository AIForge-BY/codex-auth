import AppKit
import Combine
import SwiftUI

struct StatusItemSegment: Equatable {
    let text: String
    let tone: UsageTone
}

struct StatusItemPresentation: Equatable {
    let segments: [StatusItemSegment]
    let isLoading: Bool

    /// 根据账号实际返回的窗口生成菜单栏片段，缺失的 5 小时窗口不会占位。
    init(account: CodexAccount?, isLoading: Bool) {
        self.isLoading = isLoading
        var segments: [StatusItemSegment] = []
        if let account, let fiveHour = account.usage.fiveHour, let text = account.menuBarFiveHourText {
            segments.append(StatusItemSegment(text: text, tone: fiveHour.menuBarUsageTone))
            segments.append(
                StatusItemSegment(
                    text: account.menuBarSevenDayText,
                    tone: account.usage.sevenDay.menuBarUsageTone
                )
            )
        } else {
            segments.append(
                StatusItemSegment(
                    text: account?.usage.sevenDay.menuBarPercentText ?? "--",
                    tone: account?.usage.sevenDay.menuBarUsageTone ?? .unavailable
                )
            )
        }
        self.segments = segments
    }

    var plainText: String {
        segments.map(\.text).joined(separator: "\n")
    }

    /// 预留状态项外边距和百分比胶囊内边距，避免圆角底色贴近边界。
    var minimumStatusItemLength: CGFloat {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        let textWidth = segments
            .map { ($0.text as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        let horizontalPaddingWidth: CGFloat = 12
        return ceil(textWidth + horizontalPaddingWidth)
    }

    /// 按实际片段数量计算从上到下的绘制原点，使单行和双行内容都整体垂直居中。
    func lineOrigins(containerHeight: CGFloat, textHeight: CGFloat, lineSpacing: CGFloat) -> [CGFloat] {
        guard !segments.isEmpty else {
            return []
        }
        let contentHeight = textHeight + CGFloat(segments.count - 1) * lineSpacing
        let bottomY = floor((containerHeight - contentHeight) / 2)
        return segments.indices.map { index in
            bottomY + CGFloat(segments.count - index - 1) * lineSpacing
        }
    }
}

@MainActor
final class StatusItemController: NSObject, ObservableObject {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private let statusItemView = QuotaStatusItemView(frame: NSRect(x: 0, y: 0, width: 78, height: NSStatusBar.system.thickness))
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: 78)
        super.init()
        configurePopover()
        configureStatusItemView()
        bindState()
        updateStatusItem()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 420, height: 1)
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(closeMenu: { [weak self] in
                self?.closePopover()
            })
                .environmentObject(appState)
                .frame(width: 420)
                .fixedSize(horizontal: false, vertical: true)
                .background(.regularMaterial)
        )
    }

    private func configureStatusItemView() {
        guard let button = statusItem.button else {
            return
        }
        button.image = nil
        button.title = ""
        button.attributedTitle = NSAttributedString()
        button.toolTip = "Codex Auth"
        button.target = self
        button.action = #selector(togglePopover(_:))

        statusItemView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(statusItemView)
        NSLayoutConstraint.activate([
            statusItemView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            statusItemView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            statusItemView.topAnchor.constraint(equalTo: button.topAnchor),
            statusItemView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])
    }

    private func bindState() {
        appState.$state
            .combineLatest(appState.$isLoading)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem() {
        let presentation = StatusItemPresentation(
            account: appState.state?.activeAccount,
            isLoading: appState.isLoading
        )
        statusItem.length = presentation.minimumStatusItemLength
        statusItemView.frame.size.width = presentation.minimumStatusItemLength
        statusItemView.presentation = presentation
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            stopOutsideClickMonitor()
            return
        }

        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        startOutsideClickMonitor()
        Task { @MainActor in
            await appState.refreshOnMenuOpen()
        }
    }

    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePopover()
            }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else {
                return event
            }
            if event.window == self.popover.contentViewController?.view.window {
                return event
            }
            if event.window == self.statusItem.button?.window {
                return event
            }
            self.closePopover()
            return event
        }
    }

    private func stopOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
    }

    private func closePopover() {
        guard popover.isShown else {
            stopOutsideClickMonitor()
            return
        }
        popover.performClose(nil)
        stopOutsideClickMonitor()
    }
}

extension StatusItemController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        stopOutsideClickMonitor()
    }
}

private final class QuotaStatusItemView: NSView {
    var presentation = StatusItemPresentation(account: nil, isLoading: false) {
        didSet {
            needsDisplay = true
        }
    }

    private var isHighlighted = false {
        didSet {
            needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: presentation.minimumStatusItemLength, height: NSStatusBar.system.thickness)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if isHighlighted {
            NSColor.selectedContentBackgroundColor.withAlphaComponent(0.32).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 3), xRadius: 9, yRadius: 9).fill()
        }

        drawQuotaLines()
    }

    /// 绘制额度片段，并根据当前片段数量保持整体垂直居中。
    private func drawQuotaLines() {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        let x: CGFloat = 4
        let lineSpacing: CGFloat = 10
        let textHeight = ceil(font.ascender - font.descender + font.leading)
        let lineOrigins = presentation.lineOrigins(
            containerHeight: bounds.height,
            textHeight: textHeight,
            lineSpacing: lineSpacing
        )

        for (index, segment) in presentation.segments.enumerated() {
            let y = lineOrigins[index]
            let parts = splitQuotaText(segment.text)
            let prefixAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: statusBarLabelColor,
            ]
            let percentAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: segment.tone.statusItemColor(forActiveMenuBar: true),
            ]
            (parts.prefix as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: prefixAttributes)
            let prefixWidth = (parts.prefix as NSString).size(withAttributes: prefixAttributes).width
            let percentSize = (parts.percent as NSString).size(withAttributes: percentAttributes)
            let capsuleRect = NSRect(
                x: x + prefixWidth,
                y: y - 1,
                width: ceil(percentSize.width) + 4,
                height: textHeight + 2
            )
            segment.tone.statusItemBackgroundColor(forActiveMenuBar: true).setFill()
            NSBezierPath(
                roundedRect: capsuleRect,
                xRadius: capsuleRect.height / 2,
                yRadius: capsuleRect.height / 2
            ).fill()
            (parts.percent as NSString).draw(
                at: NSPoint(x: capsuleRect.minX + 2, y: y),
                withAttributes: percentAttributes
            )
        }
    }

    private func splitQuotaText(_ text: String) -> (prefix: String, percent: String) {
        guard let spaceIndex = text.firstIndex(of: " ") else {
            return ("", text)
        }
        let prefix = String(text[...spaceIndex])
        let percent = String(text[text.index(after: spaceIndex)...])
        return (prefix, percent)
    }

    private var statusBarLabelColor: NSColor {
        NSColor.white.withAlphaComponent(0.68)
    }
}

private extension UsageTone {
    var statusItemColor: NSColor {
        statusItemColor(forActiveMenuBar: false)
    }

    func statusItemColor(forActiveMenuBar activeMenuBar: Bool) -> NSColor {
        switch self {
        case .available:
            return activeMenuBar ? NSColor(calibratedRed: 0.62, green: 0.82, blue: 0.58, alpha: 1) : NSColor(calibratedRed: 0.18, green: 0.52, blue: 0.32, alpha: 1)
        case .low:
            return activeMenuBar ? NSColor(calibratedRed: 0.92, green: 0.58, blue: 0.54, alpha: 1) : NSColor(calibratedRed: 0.78, green: 0.18, blue: 0.16, alpha: 1)
        case .unavailable:
            return activeMenuBar ? NSColor.white.withAlphaComponent(0.72) : .secondaryLabelColor
        }
    }

    /// 返回与额度状态匹配的半透明胶囊底色，并适配菜单栏高亮背景。
    func statusItemBackgroundColor(forActiveMenuBar activeMenuBar: Bool) -> NSColor {
        switch self {
        case .available:
            return NSColor(calibratedRed: 0.25, green: 0.64, blue: 0.37, alpha: activeMenuBar ? 0.28 : 0.16)
        case .low:
            return NSColor(calibratedRed: 0.86, green: 0.24, blue: 0.20, alpha: activeMenuBar ? 0.32 : 0.18)
        case .unavailable:
            return NSColor.white.withAlphaComponent(activeMenuBar ? 0.14 : 0.08)
        }
    }
}
