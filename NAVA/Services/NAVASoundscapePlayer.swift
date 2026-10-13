import Foundation
import AVFoundation
import Combine

@MainActor
final class NAVASoundscapePlayer: ObservableObject {
    enum Track: String, CaseIterable, Identifiable {
        case rain = "EmberRain"
        case space = "StillSpace"
        case night = "NightDrive"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .rain: return "باران گرم"
            case .space: return "فضای آرام"
            case .night: return "رانندگی شبانه"
            }
        }
        var detail: String {
            switch self {
            case .rain: return "بافت گرم و باران انتزاعی"
            case .space: return "مناسب تمرکز و سکوت"
            case .night: return "آرامش جاده و فضای شب"
            }
        }
        var symbol: String {
            switch self {
            case .rain: return "cloud.drizzle"
            case .space: return "moon.stars"
            case .night: return "car.side"
            }
        }
    }

    @Published private(set) var playing: Track?
    @Published var errorMessage: String?
    private var audio: AVAudioPlayer?

    func toggle(_ track: Track) {
        if playing == track { stop(); return }
        stop()
        guard let file = Bundle.main.url(forResource: track.rawValue, withExtension: "wav")
                ?? Bundle.main.url(forResource: track.rawValue, withExtension: "wav", subdirectory: "Sounds") else {
            errorMessage = "فایل صدای آفلاین در اپ پیدا نشد."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let sound = try AVAudioPlayer(contentsOf: file)
            sound.numberOfLoops = -1
            sound.volume = 0
            sound.prepareToPlay()
            guard sound.play() else { throw NSError(domain: "NAVA.Audio", code: 3) }
            sound.setVolume(0.44, fadeDuration: 1.5)
            audio = sound
            playing = track
            errorMessage = nil
        } catch {
            errorMessage = "پخش ممکن نیست: \(error.localizedDescription)"
        }
    }

    func stop() {
        audio?.stop()
        audio = nil
        playing = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
