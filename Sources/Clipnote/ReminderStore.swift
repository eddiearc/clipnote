import Combine
import EventKit
import Foundation
import ClipnoteCore

enum AccessState: Equatable {
    case unknown
    case requesting
    case authorized
    case denied
    case restricted
}

/// 进程内唯一的 EventKit 入口：授权、拉取未完成提醒、写回完成状态。
@MainActor
final class ReminderStore: ObservableObject {
    let eventStore = EKEventStore()

    @Published private(set) var access: AccessState = .unknown
    @Published private(set) var items: [ReminderItem] = []
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    private var watcher: ReminderWatcher?
    private var completingIDs = Set<String>()

    func start() async {
        await requestAccessIfNeeded()
        guard access == .authorized else { return }
        startWatcher()
        await refresh()
    }

    func requestAccessIfNeeded() async {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .fullAccess, .authorized:
            access = .authorized
        case .denied:
            access = .denied
        case .restricted:
            access = .restricted
        case .notDetermined:
            access = .requesting
            do {
                let granted = try await eventStore.requestFullAccessToReminders()
                access = granted ? .authorized : .denied
            } catch {
                access = .denied
                lastError = error.localizedDescription
            }
        default:
            access = .denied
        }
    }

    func refresh() async {
        guard access == .authorized else {
            items = []
            return
        }
        isLoading = true
        defer { isLoading = false }

        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: calendars.isEmpty ? nil : calendars
        )

        let fetched: [EKReminder] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        let mapped = fetched.compactMap { reminder -> ReminderItem? in
            guard !completingIDs.contains(reminder.calendarItemIdentifier) else { return nil }
            return ReminderMapper.item(from: reminder)
        }
        items = ReminderSort.ordered(mapped)
    }

    func complete(_ item: ReminderItem) async {
        guard access == .authorized else { return }
        completingIDs.insert(item.id)
        items.removeAll { $0.id == item.id }

        do {
            guard let reminder = eventStore.calendarItem(withIdentifier: item.id) as? EKReminder else {
                throw StoreError.missingReminder
            }
            reminder.isCompleted = true
            try eventStore.save(reminder, commit: true)
            completingIDs.remove(item.id)
            lastError = nil
        } catch {
            completingIDs.remove(item.id)
            lastError = error.localizedDescription
            await refresh()
        }
    }

    private func startWatcher() {
        guard watcher == nil else { return }
        let watcher = ReminderWatcher(store: eventStore) { [weak self] in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        watcher.start()
        self.watcher = watcher
    }
}

enum StoreError: LocalizedError {
    case missingReminder

    var errorDescription: String? {
        switch self {
        case .missingReminder:
            return "That reminder is no longer in Reminders."
        }
    }
}
