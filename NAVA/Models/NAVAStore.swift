import Foundation
import UserNotifications
import Combine

struct NAVANote: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    let createdAt: Date
    var pinnedAt: Date?

    init(text: String) {
        id = UUID()
        self.text = text
        createdAt = Date()
        pinnedAt = nil
    }

    var isPinned: Bool { pinnedAt != nil }
}

struct NAVAReminder: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var date: Date
    var completedAt: Date?

    init(title: String, date: Date) {
        id = UUID()
        self.title = title
        self.date = date
        completedAt = nil
    }

    var isCompleted: Bool { completedAt != nil }
}

enum NAVAStoreError: LocalizedError {
    case notificationPermission
    case invalidDate
    case notFound

    var errorDescription: String? {
        switch self {
        case .notificationPermission: "اعلان‌های NAVA غیرفعال هستن. از تنظیمات آیفون فعالشون کن."
        case .invalidDate: "زمان یادآوری باید در آینده باشه."
        case .notFound: "این مورد در حافظه نوا پیدا نشد."
        }
    }
}

@MainActor
final class NAVAStore: ObservableObject {
    @Published private(set) var notes: [NAVANote] = []
    @Published private(set) var reminders: [NAVAReminder] = []

    private let notesKey = "nava.notes.v1"
    private let remindersKey = "nava.reminders.v1"

    init() {
        // Keep existing v1 keys and Codable fields so previous installs migrate in-place.
        notes = decode([NAVANote].self, for: notesKey) ?? []
        reminders = decode([NAVAReminder].self, for: remindersKey) ?? []
    }

    var orderedNotes: [NAVANote] {
        notes.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.createdAt > $1.createdAt
        }
    }

    var activeReminders: [NAVAReminder] {
        reminders.filter { !$0.isCompleted }.sorted { $0.date < $1.date }
    }

    var completedReminders: [NAVAReminder] {
        reminders.filter { $0.isCompleted }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    func addNote(_ value: String) {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        notes.insert(NAVANote(text: text), at: 0)
        persistNotes()
    }

    func updateNote(id: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].text = trimmed
        persistNotes()
    }

    func togglePin(id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].pinnedAt = notes[index].isPinned ? nil : Date()
        persistNotes()
    }

    func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
        persistNotes()
    }

    func deleteNotes(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) { notes.remove(at: index) }
        persistNotes()
    }

    func addReminder(title rawTitle: String, date: Date) async throws {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        guard date > Date() else { throw NAVAStoreError.invalidDate }
        let reminder = NAVAReminder(title: title, date: date)
        try await schedule(reminder)
        reminders.insert(reminder, at: 0)
        persistReminders()
    }

    func completeReminder(id: UUID, completed: Bool) async {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        if completed {
            reminders[index].completedAt = Date()
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        } else {
            reminders[index].completedAt = nil
            if reminders[index].date > Date() {
                try? await schedule(reminders[index])
            }
        }
        persistReminders()
    }

    func updateReminder(id: UUID, title rawTitle: String, date: Date) async throws {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else {
            throw NAVAStoreError.notFound
        }
        guard date > Date() else { throw NAVAStoreError.invalidDate }
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        var updated = reminders[index]
        updated.title = title
        updated.date = date
        updated.completedAt = nil
        try await schedule(updated)
        reminders[index] = updated
        persistReminders()
    }

    func snoozeReminder(id: UUID, minutes: Int) async throws {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else {
            throw NAVAStoreError.notFound
        }
        let future = Date().addingTimeInterval(TimeInterval(max(1, minutes)) * 60)
        try await updateReminder(id: id, title: reminders[index].title, date: future)
    }

    func deleteReminder(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        reminders.removeAll { $0.id == id }
        persistReminders()
    }

    func deleteReminders(at offsets: IndexSet) {
        let ids = offsets.map { reminders[$0].id.uuidString }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        for index in offsets.sorted(by: >) { reminders.remove(at: index) }
        persistReminders()
    }

    func deleteAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: reminders.map { $0.id.uuidString }
        )
        notes = []
        reminders = []
        persistNotes()
        persistReminders()
    }

    func exportData() throws -> Data {
        struct LocalBackup: Encodable {
            let version: Int
            let exportedAt: Date
            let notes: [NAVANote]
            let reminders: [NAVAReminder]
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(LocalBackup(version: 4, exportedAt: Date(), notes: notes, reminders: reminders))
    }

    func importData(_ data: Data) async throws {
        struct LocalBackup: Decodable {
            let version: Int
            let notes: [NAVANote]
            let reminders: [NAVAReminder]
        }
        let snapshot = try JSONDecoder().decode(LocalBackup.self, from: data)
        guard snapshot.version == 4, snapshot.notes.count <= 10000,
              snapshot.reminders.count <= 10000 else { throw NAVAStoreError.notFound }
        for note in snapshot.notes where !notes.contains(where: { $0.id == note.id }) {
            notes.append(note)
        }
        for reminder in snapshot.reminders where !reminders.contains(where: { $0.id == reminder.id }) {
            reminders.append(reminder)
            if !reminder.isCompleted && reminder.date > Date() {
                try? await schedule(reminder)
            }
        }
        persistNotes()
        persistReminders()
    }

    private func schedule(_ reminder: NAVAReminder) async throws {
        let center = UNUserNotificationCenter.current()
        let authorization = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard authorization else { throw NAVAStoreError.notificationPermission }
        let notification = UNMutableNotificationContent()
        notification.title = "NAVA · یادآوری"
        notification.body = reminder.title
        notification.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
        try await center.add(
            UNNotificationRequest(
                identifier: reminder.id.uuidString,
                content: notification,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
        )
    }

    private func persistNotes() { save(notes, for: notesKey) }
    private func persistReminders() { save(reminders, for: remindersKey) }

    private func decode<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, for key: String) {
        guard let encoded = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(encoded, forKey: key)
    }
}
