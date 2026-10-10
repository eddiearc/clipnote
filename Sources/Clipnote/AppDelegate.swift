import AppKit
import Carbon
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = ReminderStore()
    private let line = LineState()
    private let hover = HoverController()

    private var panel: LinePanel!
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var cancellables = Set<AnyCancellable>()
    private var isPresent = false
    private var lastItemIDs: [String] = []
    private var didPrimeItemIDs = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingView(rootView: LineView(store: store, line: line))
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]
        panel = LinePanel(content: host)
        panel.placeOnScreen()

        configureHover()
        hover.start()
        setUpStatusItem()

        hotKey = HotKey(keyCode: Int(kVK_ANSI_R), modifiers: controlKey | optionKey) { [weak self] in
            self?.toggleLine()
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.panel.placeOnScreen()
            }
        }

        store.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                guard let self else { return }
                let ids = items.map(\.id)
                defer {
                    self.lastItemIDs = ids
                    self.didPrimeItemIDs = true
                }
                // 首次快照不弹层；之后集合变化时短暂探出，方便看到 Reminders.app 的改动。
                guard self.didPrimeItemIDs, ids != self.lastItemIDs, !ids.isEmpty else { return }
                self.hover.peek(for: 2.2)
            }
            .store(in: &cancellables)

        Task { [weak self] in
            guard let self else { return }
            await self.store.start()
            self.present()
            self.hover.pinOpen()
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                self?.hover.clearPin()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hover.stop()
    }

    private func configureHover() {
        hover.isRevealed = { [weak self] in self?.line.revealed ?? false }
        hover.panelFrame = { [weak self] in self?.panel.frame ?? .zero }
        hover.hitRects = { [weak self] in self?.line.hitRects ?? [:] }
        hover.applyMousePassthrough = { [weak self] ignore in
            self?.panel.ignoresMouseEvents = ignore
        }
        hover.onScreenChange = { [weak self] screen in
            self?.panel.placeOnScreen(screen)
        }
        hover.onReveal = { [weak self] in
            self?.reveal()
        }
        hover.onRetract = { [weak self] in
            self?.retract()
        }
    }

    private func present() {
        guard !isPresent else { return }
        isPresent = true
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    private func reveal() {
        present()
        line.revealed = true
    }

    private func retract() {
        line.revealed = false
        panel.ignoresMouseEvents = true
    }

    @objc private func toggleLine() {
        if line.revealed {
            hover.clearPin()
            retract()
        } else {
            panel.placeOnScreen()
            hover.pinOpen()
        }
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Clipnote")
        image?.isTemplate = true
        statusItem.button?.image = image
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let toggle = NSMenuItem(
            title: line.revealed ? "Hide line" : "Show line",
            action: #selector(toggleLine),
            keyEquivalent: "r"
        )
        toggle.keyEquivalentModifierMask = [.control, .option]
        toggle.target = self
        menu.addItem(toggle)

        let refresh = NSMenuItem(title: "Refresh reminders", action: #selector(refreshReminders), keyEquivalent: "")
        refresh.target = self
        menu.addItem(refresh)

        menu.addItem(.separator())

        let countTitle: String
        switch store.access {
        case .authorized:
            countTitle = store.items.isEmpty
                ? "No open reminders"
                : "\(store.items.count) open reminder\(store.items.count == 1 ? "" : "s")"
        case .denied, .restricted:
            countTitle = "Reminders access denied"
        case .requesting, .unknown:
            countTitle = "Waiting for Reminders access"
        }
        let countItem = NSMenuItem(title: countTitle, action: nil, keyEquivalent: "")
        countItem.isEnabled = false
        menu.addItem(countItem)

        if store.access == .denied || store.access == .restricted {
            let settings = NSMenuItem(title: "Open System Settings…", action: #selector(openSettings), keyEquivalent: "")
            settings.target = self
            menu.addItem(settings)
        }

        let reminders = NSMenuItem(title: "Open Reminders", action: #selector(openRemindersApp), keyEquivalent: "")
        reminders.target = self
        menu.addItem(reminders)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Clipnote", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func refreshReminders() {
        Task { await store.refresh() }
    }

    @objc private func openSettings() {
        PrivacySettings.openReminders()
    }

    @objc private func openRemindersApp() {
        PrivacySettings.openRemindersApp()
    }
}
