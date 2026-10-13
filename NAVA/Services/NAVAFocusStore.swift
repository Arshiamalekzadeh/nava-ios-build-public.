import AVFoundation
import Combine
import Foundation
import UserNotifications

enum NAVAFocusSound: String, CaseIterable, Identifiable {
    case rain = "EmberRain"
    case space = "StillSpace"
    case night = "NightDrive"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rain: "باران گرم"
        case .space: "فضای آرام"
        case .night: "رانندگی شبانه"
        }
    }

    var subtitle: String {
        switch self {
        case .rain: "بافت بارانی ملایم"
        case .space: "مناسب تمرکز"
        case .night: "فضای شب و سکوت"
        }
    }

    var icon: String {
        switch self {
        case .rain: "cloud.drizzle"
        case .space: "moon.stars"
        case .night: "car.side"
        }
    }
}

@MainActor
final class NAVAFocusStore: ObservableObject {
    @Published private(set) var endsAt: Date?
    @Published private(set) var soundPlaying = false
    @Published var selectedSound: NAVAFocusSound = .rain
    @Published var selectedMinutes = 25
    @Published var errorMessage: String?

    private let savedEndKey = "nava.focus.end.v4"
    private let notificationID = "nava.focus.done"
    private var player: AVAudioPlayer?
    private var ticker: Timer?

    init() {
        let end = UserDefaults.standard.double(forKey: savedEndKey)
        if end > Date().timeIntervalSince1970 {
            endsAt = Date(timeIntervalSince1970: end)
            startTicker()
        } else {
            UserDefaults.standard.removeObject(forKey: savedEndKey)
        }
    }

    var isActive: Bool {
        endsAt.map { $0 > Date() } ?? false
    }

    func refresh() {
        if let endsAt, endsAt <= Date() {
            self.endsAt = nil
            stopSound()
            ticker?.invalidate()
            ticker = nil
            UserDefaults.standard.removeObject(forKey: savedEndKey)
        }
    }

    func start(activity: LiveActivityManager) async {
        errorMessage = nil
        await cancel(activity: activity, preserveStatus: true)
        let minutes = max(1, min(240, selectedMinutes))
        let until = Date().addingTimeInterval(TimeInterval(minutes) * 60)
        self.endsAt = until
        startTicker()
        UserDefaults.standard.set(until.timeIntervalSince1970, forKey: savedEndKey)
        do {
            let center = UNUserNotificationCenter.current()
            if try await center.requestAuthorization(options: [.alert, .sound]) {
                let content = UNMutableNotificationContent()
                content.title = "NAVA · پایان تمرکز"
                content.body = "جلسه \(minutes) دقیقه‌ای تموم شد. وقت یک استراحته."
                content.sound = .default
                try await center.add(
                    UNNotificationRequest(
                        identifier: notificationID,
                        content: content,
                        trigger: UNTimeIntervalNotificationTrigger(
                            timeInterval: TimeInterval(minutes) * 60,
                            repeats: false
                        )
                    )
                )
            } else {
                errorMessage = "تمرکز شروع شد، ولی اعلان پایان از تنظیمات آیفون غیرفعاله."
            }
        } catch {
            errorMessage = "تمرکز شروع شد ولی اعلان پایان ثبت نشد: \(error.localizedDescription)"
        }
        await activity.start(status: "در حال تمرکز", endsAt: until)
        await activity.updateStatus("در حال تمرکز", endsAt: until)
        playSound()
    }

    func cancel(activity: LiveActivityManager, preserveStatus: Bool = false) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
        endsAt = nil
        ticker?.invalidate()
        ticker = nil
        UserDefaults.standard.removeObject(forKey: savedEndKey)
        stopSound()
        if !preserveStatus {
            await activity.updateStatus("آماده گفتگو")
        }
    }

    func playSound() {
        guard isActive, !soundPlaying else { return }
        guard let url = Bundle.main.url(forResource: selectedSound.rawValue, withExtension: "wav")
            ?? Bundle.main.url(forResource: selectedSound.rawValue, withExtension: "wav", subdirectory: "Sounds") else {
            errorMessage = "صدای محیطی در بسته نصب پیدا نشد."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
            let audio = try AVAudioPlayer(contentsOf: url)
            audio.numberOfLoops = -1
            audio.volume = 0.26
            audio.prepareToPlay()
            guard audio.play() else { return }
            player = audio
            soundPlaying = true
        } catch {
            errorMessage = "پخش صدا شروع نشد: \(error.localizedDescription)"
        }
    }

    func stopSound() {
        player?.stop()
        player = nil
        soundPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func changeSound(_ sound: NAVAFocusSound) {
        selectedSound = sound
        if soundPlaying {
            stopSound()
            playSound()
        }
    }
}
