import AVFoundation
import Combine
import Foundation
import SherpaOnnx

/// Local Farsi text-to-speech using the publicly released Piper Persian Gyro voice,
/// bundled with the official sherpa-onnx VITS runtime and eSpeak data.
/// No OpenAI API, network, iOS "fa-IR" voice or uploaded speech required.
@MainActor
final class NAVAPersianTTSService: ObservableObject {
    @Published private(set) var isSynthesizing = false
    @Published private(set) var isPlaying = false
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?
    private var playCompletion: Timer?
    private var playbackGeneration = UUID()
    private var currentAudioURL: URL?
    private weak var conversationAudio: NAVAConversationAudio?

    var isModelBundled: Bool { Self.resourcesDirectory() != nil }

    /// Synthesizes an actual WAV file off the main thread, then plays it.
    /// Returns false with a visible error if no usable sound was produced.
    @discardableResult
    func speak(_ raw: String, through conversation: NAVAConversationAudio? = nil) async -> Bool {
        guard !isSynthesizing else {
            errorMessage = "نوا هنوز داره پاسخ قبلی رو می‌سازه؛ کمی صبر کن."
            return false
        }
        guard let directory = Self.resourcesDirectory() else {
            errorMessage = "مدل صدای فارسی در فایل نصب برنامه پیدا نشد. IPA کامل را همراه منابع صدا نصب کن."
            return false
        }
        let clean = raw
            .replacingOccurrences(of: "\n", with: "؛ ")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        stop()
        let turnGeneration = playbackGeneration
        errorMessage = nil
        isSynthesizing = true

        let phrase = String(clean.prefix(550))
        do {
            let wav = try await Renderer.shared.render(text: phrase, directory: directory)
            guard turnGeneration == playbackGeneration else {
                try? FileManager.default.removeItem(at: wav)
                return false
            }
            isSynthesizing = false
            currentAudioURL = wav

            if let conversation {
                try conversation.play(wav) { [weak self] in
                    guard let self, self.playbackGeneration == turnGeneration else { return }
                    self.stop()
                }
                conversationAudio = conversation
                currentAudioURL = wav
                isPlaying = true
                return true
            }

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            let audio = try AVAudioPlayer(contentsOf: wav)
            audio.prepareToPlay()
            guard audio.play() else {
                try? FileManager.default.removeItem(at: wav)
                throw NAVAPersianTTSError.playbackFailed
            }
            player = audio
            currentAudioURL = wav
            isPlaying = true
            playCompletion?.invalidate()
            let completionTimer = Timer(
                timeInterval: max(0.4, audio.duration + 0.15),
                repeats: false
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.playbackGeneration == turnGeneration else { return }
                    self.stop()
                }
            }
            playCompletion = completionTimer
            RunLoop.main.add(completionTimer, forMode: .common)
            return true
        } catch {
            guard turnGeneration == playbackGeneration else { return false }
            isSynthesizing = false
            if let currentAudioURL { try? FileManager.default.removeItem(at: currentAudioURL) }
            currentAudioURL = nil
            errorMessage = "صدای فارسی ساخته یا پخش نشد: \(error.localizedDescription)"
            return false
        }
    }

    func stop() {
        playbackGeneration = UUID()
        isSynthesizing = false
        playCompletion?.invalidate()
        playCompletion = nil
        player?.stop()
        conversationAudio?.stopPlayback()
        conversationAudio = nil
        player = nil
        isPlaying = false
        if let currentAudioURL {
            try? FileManager.default.removeItem(at: currentAudioURL)
        }
        currentAudioURL = nil
    }

    private nonisolated static func resourcesDirectory() -> URL? {
        let root = Bundle.main.bundleURL.appendingPathComponent("PersianTTS", isDirectory: true)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: root.appendingPathComponent("fa_IR-gyro-medium.onnx").path),
              fileManager.fileExists(atPath: root.appendingPathComponent("tokens.txt").path),
              fileManager.fileExists(atPath: root.appendingPathComponent("espeak-ng-data", isDirectory: true).path)
        else { return nil }
        return root
    }

    /// Keep model loading and synthesis serial and off the main actor. A
    /// cancelled reply cannot create a second concurrent sherpa engine.
    private actor Renderer {
        static let shared = Renderer()
        private var engine: SherpaOnnxOfflineTtsWrapper?
        private var loadedDirectory: URL?

        func render(text: String, directory: URL) throws -> URL {
            try Task.checkCancellation()
            let model = directory.appendingPathComponent("fa_IR-gyro-medium.onnx").path
            let tokens = directory.appendingPathComponent("tokens.txt").path
            let eSpeak = directory.appendingPathComponent("espeak-ng-data").path

            let vits = sherpaOnnxOfflineTtsVitsModelConfig(
                model: model,
                tokens: tokens,
                dataDir: eSpeak,
                noiseScale: 0.667,
                noiseScaleW: 0.8,
                lengthScale: 1.0
            )
            let modelConfig = sherpaOnnxOfflineTtsModelConfig(
                vits: vits, numThreads: 2, debug: 0
            )
            var configuration = sherpaOnnxOfflineTtsConfig(model: modelConfig)
            if engine == nil || loadedDirectory != directory {
                let loaded = SherpaOnnxOfflineTtsWrapper(config: &configuration)
                guard loaded.tts != nil else { throw NAVAPersianTTSError.modelInitializationFailed }
                engine = loaded
                loadedDirectory = directory
            }
            guard let engine else {
                throw NAVAPersianTTSError.modelInitializationFailed
            }
            let audio = engine.generate(text: text, sid: 0, speed: 1.05)
            guard audio.n > 0, audio.sampleRate > 0 else {
                throw NAVAPersianTTSError.emptyAudio
            }
            let wav = FileManager.default.temporaryDirectory
                .appendingPathComponent("nava-farsi-\(UUID().uuidString).wav")
            guard audio.save(filename: wav.path) == 1 else {
                try? FileManager.default.removeItem(at: wav)
                throw NAVAPersianTTSError.wavWriteFailed
            }
            return wav
        }
    }
}

enum NAVAPersianTTSError: LocalizedError {
    case modelInitializationFailed
    case emptyAudio
    case wavWriteFailed
    case playbackFailed

    var errorDescription: String? {
        switch self {
        case .modelInitializationFailed: "موتور Piper نتونست مدل فارسی رو بارگذاری کنه."
        case .emptyAudio: "موتور Piper هیچ نمونه صوتی تولید نکرد."
        case .wavWriteFailed: "ذخیره فایل صوتی ساخته‌شده انجام نشد."
        case .playbackFailed: "iOS نتونست صدای تولیدشده رو پخش کنه."
        }
    }
}
