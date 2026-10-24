import AVFoundation
import Foundation
import UIKit

@MainActor
final class NAVADeviceControlService {
    private var torchDevice: AVCaptureDevice?

    func execute(_ command: NAVADeviceControlCommand, resumeVoiceAfterShortcut: Bool = false) async -> String {
        guard !Task.isCancelled else { return "" }
        switch command {
        case .brightness(let fraction): return setBrightness(fraction)
        case .brightnessChange(let delta):
            guard let screen = activeScreen else { return "صفحهٔ فعال آیفون پیدا نشد." }
            return setBrightness(Double(screen.brightness) + delta)
        case .torch(let enabled): return await setTorch(enabled)
        case .volume(let fraction): return await setVolume(fraction, resumeVoice: resumeVoiceAfterShortcut)
        case .volumeChange(let delta):
            return await setVolume(Double(AVAudioSession.sharedInstance().outputVolume) + delta, resumeVoice: resumeVoiceAfterShortcut)
        case .help:
            return "بگو «روشنایی پنجاه درصد»، «صدا رو کم کن» یا «چراغ قوه رو روشن کن». مقدار باید بین صفر و صد باشد."
        }
    }

    private var activeScreen: UIScreen? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?.screen
    }

    private func setBrightness(_ fraction: Double) -> String {
        guard fraction.isFinite, let screen = activeScreen else { return "تنظیم روشنایی در این وضعیت ممکن نیست." }
        let value = min(1, max(0, fraction))
        screen.brightness = CGFloat(value)
        return "روشنایی روی \(Int((value * 100).rounded())) درصد تنظیم شد."
    }

    private func setTorch(_ enabled: Bool) async -> String {
        guard let device = torchDevice ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch else { return "چراغ قوه روی این دستگاه در دسترس نیست." }
        if enabled {
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            guard !Task.isCancelled else { return "فرمان چراغ قوه لغو شد." }
            guard allowed else { return "برای کنترل چراغ قوه، اجازه دوربین NAVA را در تنظیمات آیفون فعال کن." }
        }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if enabled {
                guard device.isTorchAvailable, device.isTorchModeSupported(.on) else {
                    return "چراغ قوه فعلاً قابل روشن‌کردن نیست؛ شاید دوربین مشغول یا گوشی داغ باشد."
                }
                try device.setTorchModeOn(level: 1)
            } else {
                device.torchMode = .off
            }
            torchDevice = device
            return device.isTorchActive == enabled
                ? (enabled ? "چراغ قوه روشن شد." : "چراغ قوه خاموش شد.")
                : "درخواست چراغ قوه اعمال شد؛ تغییر وضعیت هنوز تأیید نشده است."
        } catch {
            return "چراغ قوه تغییر نکرد: \(error.localizedDescription)"
        }
    }

    private func setVolume(_ fraction: Double, resumeVoice: Bool) async -> String {
        guard fraction.isFinite else { return "مقدار صدا معتبر نیست." }
        guard UserDefaults.standard.bool(forKey: "nava.deviceVolumeShortcutReady") else {
            return "برای فرمان صوتی صدا، اول شورتکات تنظیم صدا را طبق راهنمای «کنترل گوشی» در تنظیمات نوا بساز."
        }
        let name = UserDefaults.standard.string(forKey: "nava.deviceVolumeShortcut") ?? "NAVA Volume"
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "نام شورتکات تنظیم صدا در تنظیمات نوا خالی است."
        }
        let value = min(1, max(0, fraction))
        let token = UUID().uuidString
        guard let destination = NAVADeviceShortcut.volumeURL(name: name, fraction: value, token: token) else {
            return "تنظیم شورتکات صدا معتبر نیست."
        }
        UserDefaults.standard.set(token, forKey: NAVADeviceShortcut.tokenKey)
        UserDefaults.standard.set(Date(), forKey: NAVADeviceShortcut.issuedAtKey)
        UserDefaults.standard.set(resumeVoice, forKey: NAVADeviceShortcut.resumeKey)
        guard await UIApplication.shared.open(destination) else {
            UserDefaults.standard.removeObject(forKey: NAVADeviceShortcut.tokenKey)
            UserDefaults.standard.removeObject(forKey: NAVADeviceShortcut.issuedAtKey)
            UserDefaults.standard.removeObject(forKey: NAVADeviceShortcut.resumeKey)
            return "برنامهٔ Shortcuts باز نشد. نصب و تنظیم شورتکات را بررسی کن."
        }
        return "درخواست صدای \(Int((value * 100).rounded())) درصد به Shortcuts فرستاده شد؛ اجرای شورتکات در همان برنامه انجام می‌شود."
    }
}
