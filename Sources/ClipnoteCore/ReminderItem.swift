import Foundation

/// 一条未完成提醒的纯数据快照，不依赖 EventKit。
public struct ReminderItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let listName: String
    public let listColor: RGBA
    public let dueDate: Date?
    public let hasDueTime: Bool
    public let priority: Int
    public let notes: String

    public init(
        id: String,
        title: String,
        listName: String,
        listColor: RGBA = .defaultList,
        dueDate: Date? = nil,
        hasDueTime: Bool = false,
        priority: Int = 0,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.listName = listName
        self.listColor = listColor
        self.dueDate = dueDate
        self.hasDueTime = hasDueTime
        self.priority = priority
        self.notes = notes
    }

    /// 无截止日期不算过期；仅有日期时按「当天结束」判断。
    public func isOverdue(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let dueDate else { return false }
        if hasDueTime {
            return dueDate < now
        }
        return calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: now)
    }

    public func isDueToday(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let dueDate else { return false }
        return calendar.isDate(dueDate, inSameDayAs: now)
    }
}

/// 列表颜色，避免 Core 依赖 AppKit。
public struct RGBA: Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public static let defaultList = RGBA(r: 0.35, g: 0.52, b: 0.86)
}
