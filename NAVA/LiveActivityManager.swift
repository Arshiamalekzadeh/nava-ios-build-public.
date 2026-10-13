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
        let states = activities.map { "\($0.activityState)" }.joined(separator: ", ")
        diagnostic = "ActivityKit: \(ActivityAuthorizationInfo().areActivitiesEnabled ? "فعال" : "غیرفعال") · Live Activities: \(activities.count) \(states) · Extension: \(hasExtension ? "نصب" : "موجود نیست")"
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
            // Clean up old terminal activities from earlier installs. Never
            // silently pretend that an ended activity is still rendering.
            let active = Activity<NAVAActivityAttributes>.activities.contains {
                $0.activityState == .active
            }
            if active { return }
            for old in Activity<NAVAActivityAttributes>.activities {
                await old.end(nil, dismissalPolicy: .immediate)
            }
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
        // NAVA 4.3 mistakenly discarded the phase argument, so every Island
        // update rendered the Ready state. Keep an explicit phase in content.
        let content = ActivityContent(
            state: NAVAActivityAttributes.ContentState(
                status: status,
                endsAt: endsAt,
                phase: phase ?? Self.inferPhase(status, endsAt: endsAt)
            ),
            staleDate: nil
        )
        for activity in Activity<NAVAActivityAttributes>.activities {
            await activity.update(content)
        }
        refreshDiagnostics()
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
