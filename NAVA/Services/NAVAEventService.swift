import Foundation
import EventKit

/// Creates a real entry in the user's selected default iOS calendar.
/// No contacts or external API credentials involved.
enum NAVAEventService {
    @MainActor
    static func create(title: String, at start: Date) async throws {
        let eventStore = EKEventStore()
        if #available(iOS 17.0, *) {
            let allowed = try await eventStore.requestFullAccessToEvents()
            guard allowed else { throw NAVAEventError.noPermission }
        } else {
            throw NAVAEventError.noPermission
        }

        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw NAVAEventError.noDefaultCalendar
        }
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = title
        event.startDate = start
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
        event.notes = "Created by NAVA after the user requested a calendar event."
        try eventStore.save(event, span: .thisEvent, commit: true)
    }
}

enum NAVAEventError: LocalizedError {
    case noPermission
    case noDefaultCalendar

    var errorDescription: String? {
        switch self {
        case .noPermission: return "برای ثبت قرار، اجازه Calendar رو به NAVA بده."
        case .noDefaultCalendar: return "تقویم پیش‌فرض برای ثبت رویداد انتخاب نشده."
        }
    }
}
