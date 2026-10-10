import Foundation

/// 未完成提醒的展示排序：过期 → 今天 → 即将到期 → 无日期，其次按时间 / 优先级 / 标题。
public enum ReminderSort {
    public static func ordered(
        _ items: [ReminderItem],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ReminderItem] {
        items.sorted { lhs, rhs in
            let left = bucket(lhs, now: now, calendar: calendar)
            let right = bucket(rhs, now: now, calendar: calendar)
            if left != right { return left < right }

            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?) where l != r:
                return l < r
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                break
            }

            let leftPriority = priorityRank(lhs.priority)
            let rightPriority = priorityRank(rhs.priority)
            if leftPriority != rightPriority { return leftPriority < rightPriority }

            let titleOrder = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if titleOrder != .orderedSame { return titleOrder == .orderedAscending }
            return lhs.id < rhs.id
        }
    }

    /// 0 过期，1 今天，2 未来，3 无截止日期。
    public static func bucket(
        _ item: ReminderItem,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        guard item.dueDate != nil else { return 3 }
        if item.isOverdue(now: now, calendar: calendar) { return 0 }
        if item.isDueToday(now: now, calendar: calendar) { return 1 }
        return 2
    }

    /// EventKit：1 高、5 中、9 低、0 无。数值越小越靠前。
    public static func priorityRank(_ priority: Int) -> Int {
        switch priority {
        case 1: return 0
        case 5: return 1
        case 9: return 2
        default: return 3
        }
    }
}
