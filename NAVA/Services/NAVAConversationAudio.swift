import AVFoundation
import Foundation

/// Shared voice-processing I/O gives the echo canceller the actual reply output.
/// Never route the microphone to the speaker or use a second recording session.
@MainActor
final class NAVAConversationAudio {
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var playbackToken = UUID()
    private var captureToken = UUID()
    private var tapInstalled = false

    var isRunning: Bool { engine?.isRunning == true }

    func start(onSamples: @escaping @MainActor ([Float]) -> Void,
               onError: @escaping @MainActor (String) -> Void) throws {
        guard !isRunning else { return }
        stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat,
                                options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
        let audioEngine = AVAudioEngine()
        engine = audioEngine
        var started = false
        defer { if !started { stop() } }
        let input = audioEngine.inputNode
        try input.setVoiceProcessingEnabled(true)
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
              let mono = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                       sampleRate: 16_000, channels: 1, interleaved: false),
              let resampler = AVAudioConverter(from: inputFormat, to: mono) else {
            throw NAVAConversationAudioError.inputUnavailable
        }
        let replyPlayer = AVAudioPlayerNode()
        audioEngine.attach(replyPlayer)
        audioEngine.connect(replyPlayer, to: audioEngine.mainMixerNode, format: nil)
        let token = captureToken
        // Converter access is confined to this tap; the microphone never enters
        // the main mixer. Only copied 16 kHz samples cross to the main actor.
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard buffer.format.sampleRate == inputFormat.sampleRate,
                  buffer.format.channelCount == inputFormat.channelCount else {
                Task { @MainActor [weak self] in
                    guard let self, self.captureToken == token else { return }
                    onError("مسیر میکروفون تغییر کرد. مکالمه را دوباره شروع کن.")
                }
                return
            }
            let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * 16_000 / inputFormat.sampleRate)) + 32
            guard let output = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: capacity) else { return }
            var suppliedInput = false
            var conversionError: NSError?
            let status = resampler.convert(to: output, error: &conversionError) { _, state in
                if suppliedInput {
                    state.pointee = .noDataNow
                    return nil
                }
                suppliedInput = true
                state.pointee = .haveData
                return buffer
            }
            if status == .error {
                let reason = conversionError?.localizedDescription ?? "تبدیل ورودی میکروفون انجام نشد."
                Task { @MainActor [weak self] in
                    guard let self, self.captureToken == token else { return }
                    onError(reason)
                }
                return
            }
            guard output.frameLength > 0, let data = output.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: data, count: Int(output.frameLength)))
            Task { @MainActor [weak self] in
                guard let self, self.captureToken == token else { return }
                onSamples(samples)
            }
        }
        tapInstalled = true
        player = replyPlayer
        do {
            audioEngine.prepare()
            try audioEngine.start()
            started = true
        } catch {
            stop()
            throw error
        }
    }

    func play(_ url: URL, onFinished: @escaping @MainActor () -> Void) throws {
        guard let engine, engine.isRunning, let player else {
            throw NAVAConversationAudioError.inputUnavailable
        }
        stopPlayback()
        let file = try AVAudioFile(forReading: url)
        engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
        let token = playbackToken
        player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.playbackToken == token else { return }
                onFinished()
            }
        }
        player.play()
    }

    func stopPlayback() {
        playbackToken = UUID()
        player?.stop()
    }

    func stop() {
        captureToken = UUID()
        stopPlayback()
        if let engine {
            engine.stop()
            if tapInstalled { engine.inputNode.removeTap(onBus: 0) }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        tapInstalled = false
        engine = nil
        player = nil
    }
}

enum NAVAConversationAudioError: LocalizedError {
    case inputUnavailable
    var errorDescription: String? { "موتور مکالمه و حذف اکو در این مسیر صوتی آماده نشد." }
}
