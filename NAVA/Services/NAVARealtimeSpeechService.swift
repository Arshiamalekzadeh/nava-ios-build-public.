import AVFoundation
import Combine
import Foundation

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
    @Published private(set) var interruptionID: UUID?
    @Published private(set) var isMonitoringReply = false

    let audio = NAVAConversationAudio()
    private var window = NAVALiveSpeechWindow()
    private var interruptionGate = NAVAInterruptionGate()
    private var generation = UUID()
    private var lastInputAt = Date()
    private var decodeTask: Task<Void, Never>?
    private var interruptionObserver: AnyCancellable?

    init() {
        interruptionObserver = NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      raw == AVAudioSession.InterruptionType.began.rawValue else { return }
                Task { @MainActor [weak self] in
                    guard let self, self.audio.isRunning else { return }
                    self.stop()
                    self.errorMessage = "مکالمه به‌خاطر وقفهٔ صوتی آیفون متوقف شد. برای ادامه میکروفون را بزن."
                }
            }
    }

    func start(using speech: NAVAOfflineSpeechService, sensitivity: Double, monitorReply: Bool = false) async throws {
        guard !isListening else { return }
        // Cancellation may still be draining a Core ML inference. Never overlap
        // it with a new turn or let its result modify the new conversation.
        let previous = decodeTask
        generation = UUID()
        decodeTask?.cancel()
        let token = generation
        await previous?.value
        guard token == generation, !Task.isCancelled else { throw CancellationError() }
        let allowed = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard token == generation, !Task.isCancelled else { throw CancellationError() }
        guard allowed else { throw NAVAVoiceMemoError.microphoneDenied }

        window = NAVALiveSpeechWindow()
        isFinalizing = false
        partialText = ""
        completedTurn = nil
        errorMessage = nil
        interruptionGate = NAVAInterruptionGate()
        interruptionID = nil
        isMonitoringReply = monitorReply
        lastInputAt = Date()
        do {
            try audio.start { [weak self] samples in
                self?.receive(samples, sensitivity: sensitivity)
            } onError: { [weak self] reason in
                self?.stop()
                self?.errorMessage = reason
            }
            isListening = true
            decodeTask = Task { @MainActor [weak self] in
                guard let self else { return }
                await self.decodeLoop(using: speech, token: token)
            }
        } catch {
            stop()
            throw error
        }
    }

    private func receive(_ samples: [Float], sensitivity: Double) {
        lastInputAt = Date()
        guard isListening else { return }
        window.append(samples, sensitivity: isMonitoringReply ? max(0.20, sensitivity) : sensitivity)
        level = window.level
        if isMonitoringReply {
            if interruptionGate.observe(isVoiceActive: window.isVoiceActive, at: window.elapsed) {
                // Stop output immediately but preserve the beginning of the
                // user's interruption in the current transcription window.
                audio.stopPlayback()
                isMonitoringReply = false
                interruptionID = UUID()
            } else if window.isComplete {
                // Do not execute a segment that never passed interruption
                // detection: it may be residual speaker echo.
                window = NAVALiveSpeechWindow()
                interruptionGate = NAVAInterruptionGate()
            }
        }
        if window.isComplete && !isMonitoringReply {
            isListening = false
            isFinalizing = true
        }
    }

    func finishReplyMonitoring() {
        guard isMonitoringReply else { return }
        isMonitoringReply = false
        // Keep the prefix if the user began speaking just before playback
        // finished, before sustained input had time to open the gate.
        if !window.hasSpeech || !window.isVoiceActive { window = NAVALiveSpeechWindow() }
        interruptionGate = NAVAInterruptionGate()
    }

    func stop() {
        generation = UUID()
        decodeTask?.cancel()
        audio.stop()
        isListening = false
        isFinalizing = false
        level = 0
        isMonitoringReply = false
        window = NAVALiveSpeechWindow()
    }

    private func decodeLoop(using speech: NAVAOfflineSpeechService, token: UUID) async {
        var lastSampleCount = 0
        while token == generation, !Task.isCancelled {
            do {
                if !audio.isRunning || (isListening && Date().timeIntervalSince(lastInputAt) > 5) {
                    throw NAVAConversationAudioError.inputUnavailable
                }
                let final = window.isComplete
                let samples = window.samples
                if isMonitoringReply || (!final && (!window.hasSpeech || samples.count - lastSampleCount < 12_800)) {
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
                audio.stop()
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
