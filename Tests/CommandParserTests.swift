import Foundation

@main
struct CommandParserTests {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-10-11T10:00:00Z")!
        var checks = 0

        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else {
                fputs("FAILED: \(message)\n", stderr)
                exit(1)
            }
            checks += 1
        }

        check(NAVACommandParser.normalized("ساعت ۶:۳۰") == "ساعت 6:30", "Persian digits normalized")
        check(NAVACommandParser.normalized("يادداشت كد") == "یادداشت کد", "Arabic letters normalized")

        if case .addNote(let body) = NAVACommandParser.parse("یادداشت کن خرید شیر") {
            check(body == "خرید شیر", "Save note body")
        } else { fatalError("Note command not parsed") }

        if case .listNotes = NAVACommandParser.parse("لیست یادداشت ها") {
            check(true, "List notes")
        } else { fatalError("List notes missing") }

        let relative = NAVACommandParser.reminderDate(in: "یادم بنداز ۲۰ دقیقه دیگه چای بخورم", now: now, calendar: calendar)!
        check(relative.timeIntervalSince(now) == 1200, "Relative 20 minutes")

        let timer = NAVACommandParser.reminderDate(in: "تایمر ۱۰ دقیقه", now: now, calendar: calendar)!
        check(timer.timeIntervalSince(now) == 600, "Ten-minute timer")

        let nextDayEvening = NAVACommandParser.reminderDate(in: "فردا ساعت ۶ عصر جلسه", now: now, calendar: calendar)!
        let parts = calendar.dateComponents([.day,.hour,.minute], from: nextDayEvening)
        check(parts.day == 12 && parts.hour == 18 && parts.minute == 0, "Tomorrow at six pm")

        let nextDayMorning = NAVACommandParser.reminderDate(in: "فردا ساعت ۶ صبح", now: now, calendar: calendar)!
        check(calendar.component(.hour, from: nextDayMorning) == 6, "Tomorrow morning")

        let withoutDay = NAVACommandParser.reminderDate(in: "یادم بنداز ساعت ۸", now: now, calendar: calendar)!
        check(calendar.component(.day, from: withoutDay) == 12, "Past hour rolls to tomorrow when date omitted")

        check(NAVACommandParser.reminderDate(in: "امروز ساعت ۸", now: now, calendar: calendar) == nil, "Explicitly past today not scheduled")
        check(NAVACommandParser.reminderDate(in: "فردا ساعت ۲۴", now: now, calendar: calendar) == nil, "Reject invalid hour")
        check(NAVACommandParser.reminderDate(in: "فردا ساعت ۱۹:۷۴", now: now, calendar: calendar) == nil, "Reject invalid minute")

        if case .mapSearch(let place) = NAVACommandParser.parse("نقشه میدان آزادی") {
            check(place == "میدان آزادی", "Map search")
        } else { fatalError("Map command not parsed") }

        if case .webSearch(let query) = NAVACommandParser.parse("سرچ کن SwiftUI") {
            check(query == "SwiftUI", "Web search")
        } else { fatalError("Web search command not parsed") }

        if case .calendarEvent(let title, let date) = NAVACommandParser.parse("قرار فردا ساعت ۱۰ صبح مصاحبه", now: now, calendar: calendar) {
            check(title.contains("مصاحبه"), "Calendar title")
            check(calendar.component(.hour, from: date) == 10, "Calendar appointment hour")
        } else { fatalError("Calendar event command not parsed") }

        if case .openChatGPT = NAVACommandParser.parse("chatgpt") {
            check(true, "ChatGPT handoff")
        } else { fatalError("ChatGPT route not parsed") }

        print("✅ \(checks) NAVA parser checks passed")
    }
}
