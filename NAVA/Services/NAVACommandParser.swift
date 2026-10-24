import Foundation

/// Pure, testable Persian/English command parser. Never claims to be a language model.
enum NAVACommand {
    case greeting
    case help
    case addNote(String)
    case countNotes
    case listNotes
    case addReminder(title: String, date: Date)
    case calendarEvent(title: String, date: Date)
    case countReminders
    case listReminders
    case currentDate
    case currentTime
    case openChatGPT
    case mapSearch(String)
    case webSearch(String)
    case deviceControl(NAVADeviceControlCommand)
    case unknown
}

enum NAVACommandParser {
    static func normalized(_ raw: String) -> String {
        let persian = Array("۰۱۲۳۴۵۶۷۸۹")
        let arabic = Array("٠١٢٣٤٥٦٧٨٩")
        var output = ""
        for char in raw {
            if let i = persian.firstIndex(of: char) {
                output.append(String(i))
            } else if let i = arabic.firstIndex(of: char) {
                output.append(String(i))
            } else {
                output.append(char)
            }
        }
        return output
            .replacingOccurrences(of: "ي", with: "ی")
            .replacingOccurrences(of: "ك", with: "ک")
            .replacingOccurrences(of: "‌", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parse(_ raw: String, now: Date = Date(), calendar: Calendar = .current) -> NAVACommand {
        let input = normalized(raw)
        let text = input.lowercased()
        guard !text.isEmpty else { return .help }

        let greetingText = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if ["سلام", "سلام نوا", "hi", "hello", "درود", "نوا سلام", "نوا", "هی نوا"].contains(greetingText) {
            return .greeting
        }
        if text.contains("راهنما") || text.contains("چه کار") || text.contains("چیکار میتونی") || text == "help" {
            return .help
        }

        if text.contains("چند یادداشت") || text.contains("تعداد یادداشت") {
            return .countNotes
        }
        if text.contains("لیست یادداشت") || text.contains("یادداشت هام") || text.contains("یادداشت ها") {
            return .listNotes
        }
        for prefix in ["یادداشت کن ", "یادداشت: ", "یادداشت ", "بنویس: "] {
            if text.hasPrefix(prefix) {
                let value = String(input.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return .addNote(value) }
            }
        }

        if text.contains("چند یادآور") || text.contains("تعداد یادآور") { return .countReminders }
        if text.contains("لیست یادآور") || text.contains("یادآور هام") || text.contains("یادآوری هام") {
            return .listReminders
        }

        if text.hasPrefix("قرار ") || text.hasPrefix("رویداد ") || text.hasPrefix("جلسه ") {
            if let time = reminderDate(in: text, now: now, calendar: calendar) {
                return .calendarEvent(title: input, date: time)
            }
            return .help
        }

        let isReminder = text.hasPrefix("یادم بنداز") || text.hasPrefix("یادآور ") ||
            text.hasPrefix("یادآوری ") || text.hasPrefix("تایمر ") || text.hasPrefix("timer ")
        if isReminder {
            if let time = reminderDate(in: text, now: now, calendar: calendar) {
                return .addReminder(title: input, date: time)
            }
            return .help
        }

        if text.contains("ساعت چنده") || text.contains("ساعت چند") || text == "time" {
            return .currentTime
        }
        if text.contains("امروز چندمه") || text.contains("تاریخ امروز") || text == "date" {
            return .currentDate
        }

        if text.contains("چت جی پی تی") || text.contains("چت جی پی تی رو باز") ||
           text.contains("chatgpt") || text.contains("هوش مصنوعی رو باز") {
            return .openChatGPT
        }

        for prefix in ["روی نقشه ", "نقشه ", "مسیر به ", "مکان "] {
            if text.hasPrefix(prefix) {
                let query = String(input.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !query.isEmpty { return .mapSearch(query) }
            }
        }

        for prefix in ["جستجو کن ", "سرچ کن ", "گوگل کن ", "بگرد دنبال ", "search "] {
            if text.hasPrefix(prefix) {
                let query = String(input.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !query.isEmpty { return .webSearch(query) }
            }
        }

        if let control = NAVADeviceControlParser.parse(text) { return .deviceControl(control) }
        return .unknown
    }

    static func reminderDate(in raw: String, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        let input = normalized(raw).lowercased()
        if let match = groups(#"(\d{1,4})\s*(دقیقه|ساعت|روز)\s*(دیگه|دیگر|بعد|آینده)"#, in: input),
           let amount = Int(match[0]), amount > 0, amount <= 1000 {
            let unit: Calendar.Component
            switch match[1] {
            case "دقیقه": unit = .minute
            case "ساعت": unit = .hour
            default: unit = .day
            }
            return calendar.date(byAdding: unit, value: amount, to: now)
        }

        // The timer form "تایمر 15 دقیقه" does not require "بعد".
        if input.hasPrefix("تایمر ") || input.hasPrefix("timer "),
           let match = groups(#"(\d{1,4})\s*(دقیقه|ساعت)"#, in: input),
           let amount = Int(match[0]), amount > 0, amount <= 1000 {
            return calendar.date(byAdding: match[1] == "ساعت" ? .hour : .minute, value: amount, to: now)
        }

        guard let time = groups(#"ساعت\s*(\d{1,2})(?:[:٫](\d{1,2}))?"#, in: input),
              var hour = Int(time[0]), (0...23).contains(hour)
        else { return nil }

        let minute = time.count > 1 && !time[1].isEmpty ? (Int(time[1]) ?? -1) : 0
        guard (0...59).contains(minute) else { return nil }

        // Interpret natural 12h phrases without overwriting explicit 24h values.
        if hour <= 12 {
            if input.contains("بعدازظهر") || input.contains("بعد از ظهر") ||
               input.contains("عصر") || input.contains("شب") {
                if hour < 12 { hour += 12 }
                else if input.contains("شب") { hour = 0 }
            } else if input.contains("صبح") && hour == 12 {
                hour = 0
            }
        }

        let start = calendar.startOfDay(for: now)
        let dayOffset: Int
        if input.contains("پس فردا") || input.contains("پسفردا") {
            dayOffset = 2
        } else if input.contains("فردا") {
            dayOffset = 1
        } else {
            dayOffset = 0
        }
        guard let day = calendar.date(byAdding: .day, value: dayOffset, to: start),
              var target = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
        else { return nil }

        // No explicit day => next upcoming occurrence; explicit past day => reject.
        if target <= now {
            if dayOffset > 0 || input.contains("امروز") { return nil }
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: target) else { return nil }
            target = tomorrow
        }
        return target
    }

    private static func groups(_ pattern: String, in input: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input))
        else { return nil }
        return (1..<match.numberOfRanges).map { index in
            guard let range = Range(match.range(at: index), in: input) else { return "" }
            return String(input[range])
        }
    }
}
