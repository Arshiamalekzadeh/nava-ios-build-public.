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
    @Published private(set) var autoListenRequested = false
    static let shortcutFlag = "nava.openVoiceRequested"

    func open(listen: Bool = false) {
        if listen { autoListenRequested = true }
        guard presentation == nil else { return }
        presentation = Presentation()
    }

    /// The launch was explicitly requested through Siri, Shortcuts or a
    /// listening deep link. Starting the microphone still requires iOS
    /// permission and a foreground NAVA Voice scene.
    func consumeAutoListen() -> Bool {
        let requested = autoListenRequested
        autoListenRequested = false
        return requested
    }

    func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "nava",
              url.host?.lowercased() == "voice" else { return }
        let action = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "action" })?.value
        if action == "close" {
            requestedAction = "close"
            open()
        } else {
            open(listen: action == "listen")
        }
    }

    func consumeShortcutFlag() {
        guard UserDefaults.standard.bool(forKey: Self.shortcutFlag) else { return }
        UserDefaults.standard.removeObject(forKey: Self.shortcutFlag)
        open(listen: true)
    }
}
