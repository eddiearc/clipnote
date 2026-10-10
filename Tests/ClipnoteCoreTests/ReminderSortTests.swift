import XCTest
@testable import ClipnoteCore

final class ReminderSortTests: XCTestCase {
    private var calendar: Calendar!
    private var now: Date!

    override func setUp() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 12))!
    }

    func testOverdueComesBeforeTodayAndUndated() {
        let overdue = item("overdue", due: date(day: 9), hasTime: false)
        let today = item("today", due: date(day: 10, hour: 18), hasTime: true)
        let later = item("later", due: date(day: 12), hasTime: false)
        let undated = item("undated")

        let ordered = ReminderSort.ordered([undated, later, today, overdue], now: now, calendar: calendar)
        XCTAssertEqual(ordered.map(\.id), ["overdue", "today", "later", "undated"])
    }

    func testDateOnlyIsOverdueOnlyAfterThatDay() {
        let dueToday = item("today", due: date(day: 10), hasTime: false)
        XCTAssertFalse(dueToday.isOverdue(now: now, calendar: calendar))
        XCTAssertTrue(dueToday.isDueToday(now: now, calendar: calendar))

        let dueYesterday = item("yesterday", due: date(day: 9), hasTime: false)
        XCTAssertTrue(dueYesterday.isOverdue(now: now, calendar: calendar))
    }

    func testTimedDueUsesExactInstant() {
        let past = item("past", due: date(day: 10, hour: 9), hasTime: true)
        let future = item("future", due: date(day: 10, hour: 16), hasTime: true)
        XCTAssertTrue(past.isOverdue(now: now, calendar: calendar))
        XCTAssertFalse(future.isOverdue(now: now, calendar: calendar))
    }

    func testHighPrioritySortsFirstWithinBucket() {
        let low = item("low", due: date(day: 11), priority: 9)
        let high = item("high", due: date(day: 11), priority: 1)
        let none = item("none", due: date(day: 11), priority: 0)
        let ordered = ReminderSort.ordered([none, low, high], now: now, calendar: calendar)
        XCTAssertEqual(ordered.map(\.id), ["high", "low", "none"])
    }

    func testTitleBreaksTies() {
        let b = item("b", title: "Buy milk")
        let a = item("a", title: "Ask Sam")
        let ordered = ReminderSort.ordered([b, a], now: now, calendar: calendar)
        XCTAssertEqual(ordered.map(\.id), ["a", "b"])
    }

    private func item(
        _ id: String,
        title: String? = nil,
        due: Date? = nil,
        hasTime: Bool = false,
        priority: Int = 0
    ) -> ReminderItem {
        ReminderItem(
            id: id,
            title: title ?? id,
            listName: "Work",
            dueDate: due,
            hasDueTime: hasTime,
            priority: priority
        )
    }

    private func date(day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }
}
