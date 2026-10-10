import AppKit
import EventKit
import ClipnoteCore

enum ReminderMapper {
    static func item(from reminder: EKReminder) -> ReminderItem {
        let title = reminder.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let due = dueDate(from: reminder.dueDateComponents)
        let notes = reminder.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ReminderItem(
            id: reminder.calendarItemIdentifier,
            title: (title?.isEmpty == false ? title! : "Untitled"),
            listName: reminder.calendar?.title ?? "Reminders",
            listColor: color(from: reminder.calendar),
            dueDate: due.date,
            hasDueTime: due.hasTime,
            priority: reminder.priority,
            notes: notes
        )
    }

    private static func dueDate(from components: DateComponents?) -> (date: Date?, hasTime: Bool) {
        guard let components else { return (nil, false) }
        let hasTime = components.hour != nil || components.minute != nil
        return (Calendar.current.date(from: components), hasTime)
    }

    private static func color(from calendar: EKCalendar?) -> RGBA {
        guard let cgColor = calendar?.cgColor, let converted = NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB) else {
            return .defaultList
        }
        return RGBA(
            r: Double(converted.redComponent),
            g: Double(converted.greenComponent),
            b: Double(converted.blueComponent),
            a: Double(converted.alphaComponent)
        )
    }
}
