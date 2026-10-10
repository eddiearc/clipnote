# Clipnote

**EN** Open Apple Reminders, clipped as sticky study memos under the menu bar.  
**中文** 把未完成的 Apple 提醒事项，像书签夹上的备忘小贴纸一样夹在菜单栏下方。

Native macOS 14+ app. Swift / AppKit + SwiftUI. EventKit only. No network, no analytics, no Obsidian, no calendar events.

The hover / hide panel is inspired by [Tendedero](https://github.com/alejandrobujan/tendedero) (MIT). This repo is a rewrite for reminder memos (not a fabric clothesline), and does not use Tendedero’s name or artwork.

---

## What it does

- Requests **Reminders full access** on first launch.
- Shows incomplete reminders (title, list, due date) as warm paper slips on a thin metal bar: fiber specks, faint rules, a dog-eared corner, and a binder clip. They pack **center-out** (most urgent in the middle, then left / right). A slight sway is decorative only.
- The bar slides down when the pointer rests in the menu bar, or via **⌃⌥R**.
- Click the circle on a slip to mark that reminder complete in EventKit (writes back to Reminders / iCloud as EventKit normally would). Clicking the title does not complete it.
- Refreshes live: a single shared `EKEventStore` observes `.EKEventStoreChanged` and refetches after a 0.4s debounce.
- If access is denied, the bar explains why and opens **System Settings → Privacy & Security → Reminders**.

---

## Build and run (macOS only)

EventKit, AppKit, and the Reminders permission prompt only work on a real Mac. **Linux CI cannot verify EventKit live.** Do not expect `swift build` of the app target to succeed on Linux.

```bash
git clone <this-repo>
cd clipnote          # or the folder you cloned
scripts/build-app.sh
open build/Clipnote.app
```

Xcode: open `Package.swift`, select the **Clipnote** executable scheme, run. Prefer the `.app` from `scripts/build-app.sh` so `Info.plist` and entitlements are embedded — a raw `swift run Clipnote` binary usually cannot show a proper Reminders TCC prompt.

### Grant Reminders access

1. Launch Clipnote.app.
2. macOS asks for Reminders access. Choose **Allow** / **Full Access**.
3. If you clicked Don’t Allow: the bar shows **Reminders access is off**. Use **Open System Settings**, then enable Clipnote under **Privacy & Security → Reminders**.
4. Quit and reopen Clipnote after changing the toggle.

### Live refresh

`ReminderWatcher` listens to `Notification.Name.EKEventStoreChanged` on the shared store. Bursts of iCloud / Reminders.app edits are coalesced by `Debouncer` (400ms), then `ReminderStore.refresh()` runs `predicateForIncompleteReminders` again. Completing a slip calls `EKEventStore.save(_:commit:)` and then rides the same change notification.

---

## 中文：构建、运行、授权

1. 在 **macOS 14+** 上执行 `scripts/build-app.sh`，然后 `open build/Clipnote.app`。
2. 首次启动会请求「提醒事项」完全访问；拒绝后可在线内按钮跳转系统设置。
3. 指针在菜单栏停约 0.25 秒，或按 **⌃⌥R**，细杆与贴纸滑出；移开后收回。
4. 点击贴纸左侧圆圈即在 EventKit 中标记完成（点标题不会完成）；在「提醒事项」app 里增删改，约 0.4 秒后自动刷新。
5. **Linux / 云端 CI 没有 EventKit**，只能编译测试 `ClipnoteCore`（排序、居中铺排与防抖）。不要在 Linux 上声称已验证提醒事项读写。

```bash
# 仅 Core，可在装了 Swift 的 Linux 上跑（排序 / 防抖 / 居中铺排，不含 EventKit）：
swift test --filter ClipnoteCoreTests
```

---

## Key files

| Path | Role |
| --- | --- |
| `Sources/Clipnote/main.swift` | Accessory `NSApplication` entry |
| `Sources/Clipnote/AppDelegate.swift` | Status item, hotkey, reveal / hide |
| `Sources/Clipnote/LinePanel.swift` | Floating `NSPanel` under the menu bar |
| `Sources/Clipnote/LineView.swift` | Thin clip bar + empty / denied / memo row |
| `Sources/Clipnote/ReminderChip.swift` | Sticky slip + peg; circle completes |
| `Sources/Clipnote/ReminderStore.swift` | Shared `EKEventStore`, fetch, complete |
| `Sources/Clipnote/ReminderWatcher.swift` | `EKEventStoreChanged` + debounce |
| `Sources/Clipnote/HoverController.swift` | Menu-bar rest, retract, click-through |
| `Sources/ClipnoteCore/` | Models, sort, center-out pack, debounce |
| `Resources/Info.plist` | `NSRemindersFullAccessUsageDescription` + `NSRemindersUsageDescription` |
| `Resources/Clipnote.entitlements` | Sandbox + Reminders |
| `scripts/build-app.sh` | Ad-hoc (or Developer ID) `.app` bundle |

---

## Privacy

Clipnote does not open network connections, does not include analytics, and only talks to EventKit on-device. iCloud sync is whatever Reminders already does; this app does not debug or replace it.

---

## Known gaps (this pass)

- Must be built and run on a real Mac. This repo was authored on Linux; EventKit was **not** executed live.
- No code signing, notarization, or App Store packaging beyond a local `codesign`.
- No full-screen Space detection (the bar may still appear over a full-screen app).
- No creating reminders, list filters, or custom hotkeys.
- `calendarItemIdentifier` can change after some iCloud merges; a vanished slip needs a refresh.
- Completing a recurring reminder follows EventKit’s default (that instance).
- `swift run` without an `.app` wrapper is not a supported way to grant TCC.

---

## License

MIT. See [LICENSE](LICENSE).
