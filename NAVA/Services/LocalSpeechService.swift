import AVFoundation
import Speech
import SwiftUI

/// Device speech input. Depending on the installed recognizer and locale,
/// speech recognition may use Apple's servers. Never an OpenAI API call.
@MainActor
final class LocalSpeechService: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var isPreparing = false
    @Published private(set) var audioLevel = 0.0
    @Published var transcript = ""
    @Published var notice: String?
    @Published private(set) var onDeviceRecognition = false

    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "fa-IR"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private let speaker = AVSpeechSynthesizer()

    func start() async {
        guard !isListening, !isPreparing else { return }
        isPreparing = true
        defer { isPreparing = false }
        notice = nil
        transcript = ""

        guard let recognizer = recognizer, recognizer.isAvailable else {
            notice = "تشخیص گفتار فارسی در این نسخه iOS فعلاً در دسترس نیست. از ورودی متنی یا ChatGPT Voice استفاده کن."
            return
        }
        let speechAuth = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechAuth == .authorized else {
            notice = "اجازه تشخیص گفتار رو از Settings به NAVA بده."
            return
        }
        let micAuth = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard micAuth else {
            notice = "اجازه دسترسی به میکروفون رو از Settings به NAVA بده."
            return
        }

        let audioRequest = SFSpeechAudioBufferRecognitionRequest()
        audioRequest.shouldReportPartialResults = true
        onDeviceRecognition = recognizer.supportsOnDeviceRecognition
        audioRequest.requiresOnDeviceRecognition = onDeviceRecognition
        request = audioRequest

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw NSError(domain: "NAVA.Audio", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "ورودی صوتی میکروفون در دسترس نیست."
                ])
            }
            if tapInstalled { input.removeTap(onBus: 0); tapInstalled = false }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self, weak audioRequest] buffer, _ in
                audioRequest?.append(buffer)
                guard let samples = buffer.floatChannelData?[0] else { return }
                let count = Int(buffer.frameLength)
                guard count > 0 else { return }
                var power: Float = 0
                for index in stride(from: 0, to: count, by: 8) {
                    let value = samples[index]
                    power += value * value
                }
                let level = min(1.0, Double(sqrt(power / Float(max(1, count / 8)))) * 7)
                Task { @MainActor [weak self] in self?.audioLevel = level }
            }
            tapInstalled = true

            task = recognizer.recognitionTask(with: audioRequest) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }
                    if let error {
                        if self.isListening {
                            self.notice = "تشخیص گفتار متوقف شد: \(error.localizedDescription)"
                            self.stop()
                        }
                    } else if result?.isFinal == true {
                        self.stop()
                    }
                }
            }

            engine.prepare()
            try engine.start()
            isListening = true
            if !onDeviceRecognition {
                notice = "تشخیص فارسی ممکنه برای پردازش از سرویس گفتار اپل استفاده کنه."
            }
        } catch {
            notice = "میکروفون شروع نشد: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        if engine.isRunning { engine.stop() }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isListening = false
        audioLevel = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speak(_ text: String) {
        guard (UserDefaults.standard.object(forKey: "nava.voiceAutoSpeak") as? Bool) ?? true else { return }
        speaker.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        guard let persianVoice = AVSpeechSynthesisVoice(language: "fa-IR") else {
            notice = "صدای فارسی در تنظیمات Speech آیفون نصب نیست. پاسخ متنی در نوا نمایش داده می‌شود."
            return
        }
        utterance.voice = persianVoice
        utterance.rate = 0.49
        speaker.speak(utterance)
    }
}
