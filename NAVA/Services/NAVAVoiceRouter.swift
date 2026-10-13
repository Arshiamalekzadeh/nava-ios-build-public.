import Foundation
import Combine

/// Single voice destination for Home, Siri Shortcuts, Action Button and
/// Dynamic Island. No microphone access is attempted by the URL handler.
@MainActor
final class NAVAVoiceRouter: ObservableObject {
    struct Presentation: Identifiable {
        let id = UUID()
    }

    @Published var presentation: Presentation?
    @Published var requestedAction: String?
    static let shortcutFlag = "nava.openVoiceRequested"

    func open() {
        guard presentation == nil else { return }
        presentation = Presentation()
    }

    func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "nava",
              url.host?.lowercased() == "voice" else { return }
        let action = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "action" })?.value
        if action == "close" {
            requestedAction = "close"
        }
        open()
    }

    func consumeShortcutFlag() {
        guard UserDefaults.standard.bool(forKey: Self.shortcutFlag) else { return }
        UserDefaults.standard.removeObject(forKey: Self.shortcutFlag)
        open()
    }
}
