import Foundation
import Combine

enum NAVARole: String, Codable {
    case nava
    case user
}

struct NAVAMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: NAVARole
    let text: String
    let createdAt: Date

    init(role: NAVARole, text: String) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.createdAt = Date()
    }
}

/// A supported action requires an explicit second tap before external navigation.
struct NAVAPendingAction: Identifiable {
    let id = UUID()
    let title: String
    let destination: URL
}

@MainActor
final class NAVAChatStore: ObservableObject {
    @Published private(set) var messages: [NAVAMessage] = []
    @Published private(set) var pendingAction: NAVAPendingAction?

    private let key = "nava.messages.v2"
    private let clock = DateFormatter()
    private let deviceControls = NAVADeviceControlService()

    init() {
        if let bytes = UserDefaults.standard.data(forKey: key),
           let history = try? JSONDecoder().decode([NAVAMessage].self, from: bytes) {
            messages = history
        } else {
            messages = [
                NAVAMessage(
                    role: .nava,
                    text: "سلام! 🖤 من نوام. فرمان‌های فارسی مثل «یادداشت کن»، «یادم بنداز ۲۰ دقیقه دیگه»، «نقشه تهران» و «سرچ کن…» رو انجام می‌دم. برای گفت‌وگوی هوشمند، حساب ChatGPT رو از تنظیمات نوا متصل کن."
                )
            ]
        }
    }

    @discardableResult
    func send(_ raw: String, store: NAVAStore) async -> String {
        let message = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return "" }
        pendingAction = nil
        messages.append(NAVAMessage(role: .user, text: message))
        let reply = await handle(NAVACommandParser.parse(message), store: store)
        messages.append(NAVAMessage(role: .nava, text: reply))
        persist()
        return reply
    }

    /// AI messages use only the explicitly authorized ChatGPT plan token.
    /// The token never enters UserDefaults, chat history or logs.
    @discardableResult
    func sendAI(_ raw: String, auth: ChatGPTAuthManager) async -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        pendingAction = nil
        messages.append(NAVAMessage(role: .user, text: text))
        persist()

        let reply: String
        do {
            let token = try await auth.accessTokenForPlan()
            reply = try await ChatGPTResponsesClient.reply(history: messages, accessToken: token)
        } catch {
            reply = "پاسخ ChatGPT دریافت نشد: \(error.localizedDescription)"
        }
        messages.append(NAVAMessage(role: .nava, text: reply))
        persist()
        return reply
    }

    private func handle(_ command: NAVACommand, store: NAVAStore) async -> String {
        switch command {
        case .greeting:
            return "سلام! خوش اومدی 🖤 بگو چی برات ثبت کنم یا کجا رو پیدا کنیم."
        case .help:
            return """
            این فرمان‌ها رو امتحان کن:
            • یادداشت کن فردا پروژه رو تحویل بدم
            • یادم بنداز فردا ساعت ۶ عصر تمرین کنم
            • یادم بنداز ۲۰ دقیقه دیگه به جلسه برسم
            • تایمر ۱۰ دقیقه
            • قرار فردا ساعت ۱۰ صبح مصاحبه کاری
            • لیست یادداشت‌ها / لیست یادآورها
            • ساعت چنده / امروز چندمه
            • نقشه میدان آزادی
            • سرچ کن آموزش SwiftUI
            • روشنایی پنجاه درصد / نور صفحه رو کم کن
            • چراغ قوه رو روشن کن / خاموش کن
            • صدا رو سی درصد کن (با شورتکات تنظیم‌شده)

            گفت‌وگوی آزاد با ChatGPT در اپ رسمی انجام می‌شه.
            """
        case .addNote(let content):
            store.addNote(content)
            return "ثبت شد؛ یادداشتت روی همین آیفون ذخیره شد. ✓"
        case .countNotes:
            return "\(store.notes.count) یادداشت داری."
        case .listNotes:
            guard !store.notes.isEmpty else { return "هنوز یادداشتی ثبت نکردی." }
            return "آخرین یادداشت‌هات:\n" +
                store.notes.prefix(5).enumerated().map { "\($0.offset + 1). \($0.element.text)" }.joined(separator: "\n")
        case .addReminder(let title, let date):
            do {
                try await store.addReminder(title: title, date: date)
                return "یادآوری ثبت شد ✓\n\(date.formatted(.dateTime.day().month().year().hour().minute()))"
            } catch {
                return "یادآور ثبت نشد: \(error.localizedDescription)"
            }
        case .calendarEvent(let title, let date):
            do {
                try await NAVAEventService.create(title: title, at: date)
                return "قرار در تقویم آیفون ثبت شد ✓\nشروع: \(date.formatted(.dateTime.day().month().year().hour().minute()))\nمدت: یک ساعت"
            } catch {
                return "ثبت قرار انجام نشد: \(error.localizedDescription)"
            }
        case .countReminders:
            let future = store.reminders.filter { $0.date > Date() }.count
            return "\(future) یادآور آینده داری."
        case .listReminders:
            let upcoming = store.reminders.filter { $0.date > Date() }.sorted { $0.date < $1.date }
            guard !upcoming.isEmpty else { return "فعلاً یادآور آینده نداری." }
            return upcoming.prefix(5).map {
                "• \($0.title) — \($0.date.formatted(.dateTime.day().month().hour().minute()))"
            }.joined(separator: "\n")
        case .currentDate:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fa_IR")
            formatter.calendar = Calendar(identifier: .persian)
            formatter.dateStyle = .full
            return "امروز \(formatter.string(from: Date())) هست."
        case .currentTime:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fa_IR")
            formatter.timeStyle = .short
            return "الان ساعت \(formatter.string(from: Date())) هست."
        case .openChatGPT:
            pendingAction = NAVAPendingAction(
                title: "رفتن به ChatGPT",
                destination: URL(string: "https://chatgpt.com")!
            )
            return "برای گفت‌وگوی هوشمند، روی «رفتن به ChatGPT» بزن. حساب Plus تو اونجا فعاله، نه در خود NAVA."
        case .mapSearch(let place):
            var components = URLComponents(string: "https://maps.apple.com/")
            components?.queryItems = [URLQueryItem(name: "q", value: place)]
            if let url = components?.url {
                pendingAction = NAVAPendingAction(title: "بازکردن نقشه: \(place)", destination: url)
            }
            return "مقصد «\(place)» آماده شد. برای دیدن نتایج در Apple Maps، دکمه پایین رو بزن."
        case .webSearch(let term):
            var components = URLComponents(string: "https://www.google.com/search")
            components?.queryItems = [URLQueryItem(name: "q", value: term)]
            if let url = components?.url {
                pendingAction = NAVAPendingAction(title: "جستجوی «\(term)»", destination: url)
            }
            return "جستجوی «\(term)» آماده شد. دکمه پایین رو بزن تا نتایج باز بشن."
        case .deviceControl(let command):
            return await deviceControls.execute(command)
        case .unknown:
            return "این دستور رو هنوز نمی‌شناسم. «راهنما» رو بفرست تا فرمان‌های پشتیبانی‌شده رو ببینی. برای سؤال‌های آزاد می‌تونی مستقیم بری ChatGPT."
        }
    }

    func dismissAction() {
        pendingAction = nil
    }

    func clear() {
        pendingAction = nil
        messages = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
