import AppKit

/// 贴在菜单栏下方的透明浮动条：不抢焦点，默认点击穿透。
final class LinePanel: NSPanel {
    init(content: NSView) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovable = false
        becomesKeyOnlyIfNeeded = true
        ignoresMouseEvents = true
        contentView = content
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    static func screenUnderPointer() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    func placeOnScreen(_ screen: NSScreen? = nil) {
        guard let visible = (screen ?? Self.screenUnderPointer())?.visibleFrame else { return }
        let target = NSRect(
            x: visible.minX,
            y: visible.maxY - Layout.panelHeight,
            width: visible.width,
            height: Layout.panelHeight
        )
        if frame != target {
            setFrame(target, display: true)
        }
    }
}
