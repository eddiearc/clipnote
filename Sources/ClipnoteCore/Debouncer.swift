import Foundation

/// 把短时间内的多次回调合并成一次，用于 EventKit 变更通知。
public final class Debouncer: @unchecked Sendable {
    private let interval: TimeInterval
    private let queue: DispatchQueue
    private var workItem: DispatchWorkItem?
    private let lock = NSLock()

    public init(interval: TimeInterval = 0.4, queue: DispatchQueue = .main) {
        self.interval = interval
        self.queue = queue
    }

    public func schedule(_ block: @escaping @Sendable () -> Void) {
        let item = DispatchWorkItem(block: block)
        lock.lock()
        workItem?.cancel()
        workItem = item
        lock.unlock()
        queue.asyncAfter(deadline: .now() + interval, execute: item)
    }

    public func cancel() {
        lock.lock()
        workItem?.cancel()
        workItem = nil
        lock.unlock()
    }
}
