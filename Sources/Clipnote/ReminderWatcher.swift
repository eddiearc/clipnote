import EventKit
import Foundation
import ClipnoteCore

/// 监听 `.EKEventStoreChanged`，防抖后通知刷新。
final class ReminderWatcher {
    private let store: EKEventStore
    private let onChange: @Sendable () -> Void
    private let debouncer = Debouncer(interval: 0.4, queue: .main)
    private var observer: NSObjectProtocol?

    init(store: EKEventStore, onChange: @escaping @Sendable () -> Void) {
        self.store = store
        self.onChange = onChange
    }

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: nil
        ) { [debouncer, onChange] _ in
            debouncer.schedule(onChange)
        }
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        debouncer.cancel()
    }

    deinit {
        stop()
    }
}
