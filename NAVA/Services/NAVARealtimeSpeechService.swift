import AVFoundation
import Combine
import Foundation
import WhisperKit

/// One microphone owner and one sequential decoder. Audio never leaves the device.
@MainActor
final class NAVARealtimeSpeechService: ObservableObject {
    struct Turn: Identifiable {
        let id = UUID()
        let text: String
    }

    @Published private(set) var isListening = false
    @Published private(set) var isFinalizing = false
    @Published private(set) var partialText = ""
    @Published private(set) var level = 0.0
    @Published private(set) var completedTurn: Turn?
    @Published private(set) var errorMessage: String?

    private var processor: AudioProcessor?
    private var window = NAVALiveSpeechWindow()
    private var generation = UUID()
    private var decodeTask: Task<Void, Never>?
    private var interruptionObserver: AnyCancellable?

    init() {
        interruptionObserver = NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      raw == AVAudioSession.InterruptionType.began.rawValue else { return }
                Task { @MainActor [weak self] in
                    guard let self, self.isListening || self.isFinalizing else { return }
                    self.stop()
                    self.errorMessage = "مکالمه به‌خاطر وقفهٔ صوتی آیفون متوقف شد. برای ادامه میکروفون را بزن."
                }
            }
    }

    func start(using speech: NAVAOfflineSpeechService, sensitivity: Double) async throws {
        guard !isListening else { return }
        // Cancellation may still be draining a Core ML inference. Never overlap
        // it with a new turn or let its result modify the new conversation.
        let previous = decodeTask
        stop()
        let token = generation
        await previous?.value
        guard token == generation, !Task.isCancelled else { throw CancellationError() }
        let allowed = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard token == generation, !Task.isCancelled else { throw CancellationError() }
        guard allowed else { throw NAVAVoiceMemoError.microphoneDenied }

        window = NAVALiveSpeechWindow()
        partialText = ""
        completedTurn = nil
        errorMessage = nil
        let input = AudioProcessor()
        processor = input
        do {
            try input.startRecordingLive { [weak self, weak input] samples in
                // This callback runs on the processor's audio queue. Its own
                // redundant history is not used; retain only the energy window.
                input?.purgeAudioSamples(keepingLast: 0)
                if let input, input.audioEnergy.count > 30 {
                    input.audioEnergy.removeFirst(input.audioEnergy.count - 30)
                }
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token, self.isListening else { return }
                    self.window.append(samples, sensitivity: sensitivity)
                    self.level = self.window.level
                    if self.window.isComplete {
                        self.isListening = false
                        self.isFinalizing = true
                        self.processor?.stopRecording()
                        self.processor = nil
                    }
                }
            }
            isListening = true
            decodeTask = Task { @MainActor [weak self] in
                guard let self else { return }
                await self.decodeLoop(using: speech, token: token)
            }
        } catch {
            input.stopRecording()
            processor = nil
            throw error
        }
    }

    func stop() {
        generation = UUID()
        decodeTask?.cancel()
        processor?.stopRecording()
        processor = nil
        isListening = false
        isFinalizing = false
        level = 0
        window = NAVALiveSpeechWindow()
    }

    private func decodeLoop(using speech: NAVAOfflineSpeechService, token: UUID) async {
        var lastSampleCount = 0
        while token == generation, !Task.isCancelled {
            do {
                let final = window.isComplete
                let samples = window.samples
                if !final && (!window.hasSpeech || samples.count - lastSampleCount < 12_800) {
                    try await Task.sleep(nanoseconds: 100_000_000)
                    continue
                }
                lastSampleCount = samples.count
                let text = try await speech.transcribe(samples: samples)
                guard token == generation, !Task.isCancelled else { return }
                if !text.isEmpty { partialText = text }
                if final {
                    isFinalizing = false
                    level = 0
                    decodeTask = nil
                    // A final decode replaces the hypothesis. Never execute an
                    // older partial if the final pass finds only silence.
                    completedTurn = Turn(text: text)
                    return
                }
            } catch {
                guard token == generation, !Task.isCancelled else { return }
                processor?.stopRecording()
                processor = nil
                isListening = false
                isFinalizing = false
                level = 0
                decodeTask = nil
                errorMessage = "تشخیص زنده متوقف شد: \(error.localizedDescription)"
                return
            }
        }
    }
}
