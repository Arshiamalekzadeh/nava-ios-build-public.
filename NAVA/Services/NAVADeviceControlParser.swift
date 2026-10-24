import Foundation

enum NAVADeviceControlCommand: Equatable {
    case brightness(Double)
    case brightnessChange(Double)
    case volume(Double)
    case volumeChange(Double)
    case torch(Bool)
    case help
}

enum NAVADeviceShortcut {
    static let tokenKey = "nava.volume.callbackToken"
    static let issuedAtKey = "nava.volume.callbackIssuedAt"
    static let resumeKey = "nava.volume.callbackResumeVoice"
    enum Status: String { case success, cancel, error }

    static func volumeURL(name: String, fraction: Double, token: String) -> URL? {
        guard fraction.isFinite, (0...1).contains(fraction), !token.isEmpty,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var request = URLComponents(string: "shortcuts://x-callback-url/run-shortcut")!
        request.queryItems = [URLQueryItem(name: "name", value: name),
                              URLQueryItem(name: "input", value: "text"),
                              URLQueryItem(name: "text", value: String(fraction))]
        for status in [Status.success, .cancel, .error] {
            var callback = URLComponents(string: "nava://device-volume")!
            callback.queryItems = [URLQueryItem(name: "token", value: token),
                                   URLQueryItem(name: "status", value: status.rawValue)]
            request.queryItems?.append(URLQueryItem(name: "x-\(status.rawValue)", value: callback.url!.absoluteString))
        }
        return request.url
    }

    static func callbackStatus(_ url: URL, expectedToken: String, issuedAt: Date, now: Date = Date()) -> Status? {
        guard url.scheme?.lowercased() == "nava", url.host?.lowercased() == "device-volume",
              !expectedToken.isEmpty, (0...300).contains(now.timeIntervalSince(issuedAt)),
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        let tokens = items.filter { $0.name == "token" }
        let statuses = items.filter { $0.name == "status" }
        guard tokens.count == 1, tokens.first?.value == expectedToken,
              statuses.count == 1, let raw = statuses.first?.value else { return nil }
        return Status(rawValue: raw)
    }
}

enum NAVADeviceControlParser {
    static func parse(_ raw: String) -> NAVADeviceControlCommand? {
        var text = NAVACommandParser.normalized(raw).lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if text.hasPrefix("نوا ") { text = String(text.dropFirst(4)) }
        let prefixes: [(String, Int)] = [
            ("چراغ قوه", 0), ("چراغقوه", 0), ("فلش گوشی", 0),
            ("روشنایی صفحه", 1), ("روشنایی", 1), ("نور صفحه", 1), ("نور گوشی", 1),
            ("صدای گوشی", 2), ("صدای رسانه", 2), ("ولوم", 2), ("صدا", 2)
        ]
        for (prefix, kind) in prefixes where text == prefix || text.hasPrefix(prefix + " ") {
            let filler: Set<String> = ["رو", "را", "روی", "به", "کن", "بکن", "بذار", "بزار", "تنظیم", "درصد"]
            let words = text.dropFirst(prefix.count).split(whereSeparator: { $0.isWhitespace })
                .map(String.init).filter { !filler.contains($0) }
            guard !words.contains("نکن"), !words.contains("نشه") else { return .help }
            let value = words.joined(separator: " ")
            if kind == 0 {
                switch value {
                case "روشن", "روشنش": return .torch(true)
                case "خاموش", "خاموشش": return .torch(false)
                default: return .help
                }
            }
            let delta: Double?
            switch value {
            case "زیاد", "بیشتر", "بلند", "بالا", "ببر بالا": delta = 0.1
            case "کم", "کمتر", "پایین", "بیار پایین": delta = -0.1
            default: delta = nil
            }
            if let delta { return kind == 1 ? .brightnessChange(delta) : .volumeChange(delta) }
            if kind == 2 && ["قطع", "بی صدا", "خاموش"].contains(value) { return .volume(0) }
            let number = Int(value) ?? spokenPercentage(value)
            guard let number, (0...100).contains(number) else { return .help }
            let fraction = Double(number) / 100
            return kind == 1 ? .brightness(fraction) : .volume(fraction)
        }
        return nil
    }

    private static func spokenPercentage(_ value: String) -> Int? {
        let numbers = ["صفر": 0, "یک": 1, "دو": 2, "سه": 3, "چهار": 4, "پنج": 5,
                       "شش": 6, "هفت": 7, "هشت": 8, "نه": 9, "ده": 10, "یازده": 11,
                       "دوازده": 12, "سیزده": 13, "چهارده": 14, "پانزده": 15,
                       "شانزده": 16, "هفده": 17, "هجده": 18, "نوزده": 19,
                       "بیست": 20, "سی": 30, "چهل": 40, "پنجاه": 50, "شصت": 60,
                       "هفتاد": 70, "هشتاد": 80, "نود": 90, "صد": 100]
        if let number = numbers[value] { return number }
        let parts = value.components(separatedBy: " و ")
        guard parts.count == 2, let tens = numbers[parts[0]], let units = numbers[parts[1]],
              (20...90).contains(tens), tens % 10 == 0, (1...9).contains(units) else { return nil }
        return tens + units
    }
}
