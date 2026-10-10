import AppKit

/// 指针停在菜单栏时滑出备忘夹，离开后收回；菜单栏点击会暂时抑制。
@MainActor
final class HoverController {
    var onReveal: (() -> Void)?
    var onRetract: (() -> Void)?
    var onScreenChange: ((NSScreen) -> Void)?
    var isRevealed: () -> Bool = { false }
    var panelFrame: () -> NSRect = { .zero }
    var hitRects: () -> [String: CGRect] = { [:] }
    var applyMousePassthrough: ((Bool) -> Void)?

    private var timer: Timer?
    private var clickMonitors: [Any] = []
    private var hotZoneSince: Date?
    private var awaySince: Date?
    private var menuBarSuppressed = false
    private var pinned = false
    private var peekUntil = Date.distantPast

    private static let revealDelay: TimeInterval = 0.25
    private static let retractDelay: TimeInterval = 0.5

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        watchMenuBarClicks()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        clickMonitors.forEach { NSEvent.removeMonitor($0) }
        clickMonitors.removeAll()
        applyMousePassthrough?(true)
    }

    func pinOpen() {
        pinned = true
        peekUntil = .distantPast
        awaySince = nil
        onReveal?()
    }

    func peek(for seconds: TimeInterval) {
        peekUntil = Date().addingTimeInterval(seconds)
        awaySince = nil
        onReveal?()
    }

    func clearPin() {
        pinned = false
        peekUntil = .distantPast
    }

    static func menuBarBand(of screen: NSScreen) -> NSRect {
        var height = screen.frame.maxY - screen.visibleFrame.maxY
        if height < 1 {
            height = max(NSStatusBar.system.thickness, screen.safeAreaInsets.top)
        }
        return NSRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - height,
            width: screen.frame.width,
            height: height
        )
    }

    private func watchMenuBarClicks() {
        let handler: (NSEvent?) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let point = NSEvent.mouseLocation
                // 点在绳子面板或芯片上时不收回，避免和菜单栏热区重叠。
                if self.isClickOnLine(point) { return }
                let inBar = NSScreen.screens.contains {
                    NSMouseInRect(point, Self.menuBarBand(of: $0), false)
                }
                guard inBar else { return }
                self.menuBarSuppressed = true
                self.hotZoneSince = nil
                if self.isRevealed() {
                    self.pinned = false
                    self.onRetract?()
                }
            }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: handler) {
            clickMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { event in
            handler(event)
            return event
        }) {
            clickMonitors.append(local)
        }
    }

    private func tick() {
        let mouse = NSEvent.mouseLocation
        let now = Date()
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
        let inMenuBar = screen.map { NSMouseInRect(mouse, Self.menuBarBand(of: $0), false) } ?? false
        if !inMenuBar { menuBarSuppressed = false }

        guard isRevealed() else {
            if let screen, inMenuBar, !menuBarSuppressed {
                let since = hotZoneSince ?? now
                hotZoneSince = since
                if now.timeIntervalSince(since) >= Self.revealDelay {
                    hotZoneSince = nil
                    onScreenChange?(screen)
                    onReveal?()
                }
            } else {
                hotZoneSince = nil
            }
            return
        }

        updatePassthrough(mouse)

        var zone = panelFrame()
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSPoint(x: zone.midX, y: zone.midY), $0.frame, false) }) {
            zone.size.height = screen.frame.maxY - zone.minY
        }
        let inside = NSMouseInRect(mouse, zone, false)
        if inside && pinned { pinned = false }

        let overChip = isOverChip(mouse)
        let busy = pinned || now < peekUntil || overChip
        if inside || busy {
            awaySince = nil
        } else {
            let since = awaySince ?? now
            awaySince = since
            if now.timeIntervalSince(since) >= Self.retractDelay {
                awaySince = nil
                onRetract?()
            }
        }
    }

    /// 点击落在面板（略外扩）或任一芯片的全局命中框内。
    private func isClickOnLine(_ point: NSPoint) -> Bool {
        let frame = panelFrame()
        if !frame.isEmpty, NSMouseInRect(point, frame.insetBy(dx: -8, dy: -8), false) {
            return true
        }
        return isOverChip(point)
    }

    /// SwiftUI 命中框是面板内、原点在左上；转成屏幕坐标再判断。
    private func isOverChip(_ mouse: NSPoint) -> Bool {
        let frame = panelFrame()
        return hitRects().values.contains { local in
            let global = CGRect(
                x: frame.minX + local.minX,
                y: frame.maxY - local.maxY,
                width: local.width,
                height: local.height
            ).insetBy(dx: -6, dy: -6)
            return NSMouseInRect(mouse, global, false)
        }
    }

    private func updatePassthrough(_ mouse: NSPoint) {
        applyMousePassthrough?(!isOverChip(mouse))
    }
}
