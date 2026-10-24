import Foundation
import Combine
import AVFoundation

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
    @Published private(set) var lastDeviceControlResult: String?
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
        if url.scheme?.lowercased() == "nava", url.host?.lowercased() == "device-volume" {
            handleVolumeReturn(url)
            return
        }
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

    private func handleVolumeReturn(_ url: URL) {
        let defaults = UserDefaults.standard
        guard let token = defaults.string(forKey: NAVADeviceShortcut.tokenKey),
              let issuedAt = defaults.object(forKey: NAVADeviceShortcut.issuedAtKey) as? Date,
              let status = NAVADeviceShortcut.callbackStatus(url, expectedToken: token, issuedAt: issuedAt) else { return }
        let resume = defaults.bool(forKey: NAVADeviceShortcut.resumeKey)
        defaults.removeObject(forKey: NAVADeviceShortcut.tokenKey)
        defaults.removeObject(forKey: NAVADeviceShortcut.issuedAtKey)
        defaults.removeObject(forKey: NAVADeviceShortcut.resumeKey)
        switch status {
        case .success:
            let percent = Int((AVAudioSession.sharedInstance().outputVolume * 100).rounded())
            lastDeviceControlResult = "از Shortcuts برگشتی؛ صدای فعلی گزارش‌شدهٔ آیفون \(percent) درصد است."
        case .cancel:
            lastDeviceControlResult = "اجرای شورتکات صدا لغو شد."
        case .error:
            lastDeviceControlResult = "Shortcuts برای اجرای فرمان صدا خطا گزارش کرد. تنظیم شورتکات را بررسی کن."
        }
        if resume { open(listen: true) }
    }

    func consumeShortcutFlag() {
        guard UserDefaults.standard.bool(forKey: Self.shortcutFlag) else { return }
        UserDefaults.standard.removeObject(forKey: Self.shortcutFlag)
        open(listen: true)
    }
}
