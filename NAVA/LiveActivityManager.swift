import ActivityKit
import SwiftUI

@MainActor
final class LiveActivityManager: ObservableObject {
    @Published private(set) var isRunning: Bool
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published private(set) var diagnostic = ""

    func refreshDiagnostics() {
        let activities = Activity<NAVAActivityAttributes>.activities
        isRunning = !activities.isEmpty
        let extensionURL = Bundle.main.bundleURL.appendingPathComponent("PlugIns/NAVAWidgetExtension.appex")
        let hasExtension = FileManager.default.fileExists(atPath: extensionURL.path)
        diagnostic = "ActivityKit: \(ActivityAuthorizationInfo().areActivitiesEnabled ? "فعال" : "غیرفعال") · Live Activities: \(activities.count) · Extension: \(hasExtension ? "نصب" : "موجود نیست")"
    }

    init() {
        isRunning = !Activity<NAVAActivityAttributes>.activities.isEmpty
    }

    func start(status: String = "آماده", endsAt: Date? = nil, phase: NAVAIslandPhase? = nil) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil
        refreshDiagnostics()

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            errorMessage = "Live Activities در تنظیمات آیفون غیرفعال است."
            return
        }
        if !Activity<NAVAActivityAttributes>.activities.isEmpty {
            isRunning = true
            return
        }

        do {
            let attributes = NAVAActivityAttributes(title: "NAVA", startedAt: Date())
            let content = ActivityContent(
                state: NAVAActivityAttributes.ContentState(status: status, endsAt: endsAt, phase: phase ?? Self.inferPhase(status, endsAt: endsAt)),
                staleDate: nil
            )
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            refreshDiagnostics()
        } catch {
            errorMessage = error.localizedDescription
        }
        refreshDiagnostics()
    }

    func updateStatus(_ status: String, endsAt: Date? = nil, phase: NAVAIslandPhase? = nil) async {
        let content = ActivityContent(
            state: NAVAActivityAttributes.ContentState(status: status, endsAt: endsAt),
            staleDate: nil
        )
        for activity in Activity<NAVAActivityAttributes>.activities {
            await activity.update(content)
        }
    }

    private static func inferPhase(_ status: String, endsAt: Date?) -> NAVAIslandPhase {
        if endsAt != nil || status.contains("تمرکز") { return .focus }
        if status.contains("گوش") || status.contains("شن") { return .listening }
        if status.contains("تشخیص") || status.contains("پردازش") ||
           status.contains("تبدیل") || status.contains("آماده‌سازی") { return .processing }
        if status.contains("پاسخ") || status.contains("جواب") { return .responding }
        if status.contains("ضبط") { return .recording }
        return .ready
    }

    func stop() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        for activity in Activity<NAVAActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        refreshDiagnostics()
    }
}
