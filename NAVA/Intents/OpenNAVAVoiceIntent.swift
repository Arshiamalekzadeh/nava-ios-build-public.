import AppIntents
import Foundation

/// Runs through Siri / Shortcuts and opens the native NAVA Voice screen.
/// This intent does not claim to replace Siri or listen in the background.
struct OpenNAVAVoiceIntent: AppIntent {
    static var title: LocalizedStringResource = "Talk to NAVA"
    static var description = IntentDescription("Open the NAVA voice assistant.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: NAVAVoiceRouter.shortcutFlag)
        NotificationCenter.default.post(name: Notification.Name("NAVAOpenVoiceRequested"), object: nil)
        return .result()
    }
}

