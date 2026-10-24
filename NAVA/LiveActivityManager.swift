import ActivityKit
import SwiftUI

@MainActor
final class LiveActivityManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published private(set) var diagnostic = ""
    private var pendingOperation: Task<Void, Never>?

    private var liveActivities: [Activity<NAVAActivityAttributes>] {
        Activity<NAVAActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    func refreshDiagnostics() {
        let activities = Activity<NAVAActivityAttributes>.activities
        isRunning = !liveActivities.isEmpty
        let extensionURL = Bundle.main.bundleURL.appendingPathComponent("PlugIns/NAVAWidgetExtension.appex")
        let hasExtension = FileManager.default.fileExists(atPath: extensionURL.path)
        let states = activities.map { "\($0.activityState)" }.joined(separator: ", ")
        diagnostic = "ActivityKit: \(ActivityAuthorizationInfo().areActivitiesEnabled ? "فعال" : "غیرفعال") · Live Activities: \(activities.count) \(states) · Extension: \(hasExtension ? "نصب" : "موجود نیست")"
    }

    // Serialize transitions so a close is never dropped while an update is
    // suspended, and older content cannot overtake a newer voice phase.
    private func perform(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = pendingOperation
        let next = Task { @MainActor in
            await previous?.value
            self.isWorking = true
            await operation()
            self.refreshDiagnostics()
            self.isWorking = false
        }
        pendingOperation = next
        await next.value
    }

    func start(status: String = "آماده", endsAt: Date? = nil, phase: NAVAIslandPhase? = nil) async {
        await perform {
            await self.setStatus(status, endsAt: endsAt,
                                 phase: phase ?? Self.inferPhase(status, endsAt: endsAt), allowStart: true)
        }
    }

    func updateStatus(_ status: String, endsAt: Date? = nil, phase: NAVAIslandPhase? = nil) async {
        let resolved = phase ?? Self.inferPhase(status, endsAt: endsAt)
        await perform {
            await self.setStatus(status, endsAt: endsAt, phase: resolved, allowStart: resolved != .ready)
        }
    }

    private func setStatus(_ status: String, endsAt: Date?, phase: NAVAIslandPhase, allowStart: Bool) async {
        errorMessage = nil
        let content = ActivityContent(
            state: NAVAActivityAttributes.ContentState(status: status, endsAt: endsAt, phase: phase),
            staleDate: endsAt
        )
        // Stale activities remain visible and can be updated in place.
        if let current = liveActivities.first {
            await current.update(content)
            for duplicate in liveActivities where duplicate.id != current.id {
                await duplicate.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        guard allowStart else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            errorMessage = "Live Activities در تنظیمات آیفون غیرفعال است."
            return
        }
        let extensionURL = Bundle.main.bundleURL.appendingPathComponent("PlugIns/NAVAWidgetExtension.appex")
        guard FileManager.default.fileExists(atPath: extensionURL.path) else {
            errorMessage = "افزونهٔ داینامیک آیلند در نصب موجود نیست. IPA باید همراه Widget Extension امضا و نصب شود."
            return
        }
        for old in Activity<NAVAActivityAttributes>.activities {
            await old.end(nil, dismissalPolicy: .immediate)
        }
        do {
            _ = try Activity.request(
                attributes: NAVAActivityAttributes(title: "NAVA", startedAt: Date()),
                content: content, pushType: nil
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func inferPhase(_ status: String, endsAt: Date?) -> NAVAIslandPhase {
        if endsAt != nil || status.contains("تمرکز") { return .focus }
        if status.contains("تشخیص") || status.contains("پردازش") ||
           status.contains("تبدیل") || status.contains("آماده‌سازی") { return .processing }
        if status.contains("گوش") || status.contains("شن") { return .listening }
        if status.contains("پاسخ") || status.contains("جواب") { return .responding }
        if status.contains("ضبط") { return .recording }
        return .ready
    }

    func stop() async {
        await perform {
            for activity in Activity<NAVAActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
