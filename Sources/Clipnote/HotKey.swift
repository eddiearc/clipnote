import Carbon
import Foundation

/// 全局快捷键，使用 Carbon 注册，不需要辅助功能权限。
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private let identifier: UInt32
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var handlerInstalled = false

    init(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        identifier = UInt32(bitPattern: Int32(keyCode ^ modifiers ^ 0x5049))
        HotKey.handlers[identifier] = handler
        Self.installHandlerIfNeeded()

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            let id = hotKeyID.id
            DispatchQueue.main.async {
                HotKey.handlers[id]?()
            }
            return noErr
        }, 1, &spec, nil, nil)

        let hotKeyID = EventHotKeyID(signature: OSType(0x5049_4E4C), id: identifier) // "PINL"
        RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        HotKey.handlers[identifier] = nil
    }

    private static func installHandlerIfNeeded() {
        handlerInstalled = true
    }
}
