import Foundation

/// Bounded, in-memory 16 kHz input for one conversational turn.
/// Partial decodes replace hypotheses; only the completed turn may be executed.
struct NAVALiveSpeechWindow {
    static let sampleRate = 16_000
    private(set) var samples: [Float] = []
    private(set) var isComplete = false
    private(set) var level = 0.0
    private(set) var elapsed = 0.0
    private var detector = NAVAVoiceActivityDetector()

    var hasSpeech: Bool { detector.heardSpeech }
    var isVoiceActive: Bool { detector.isVoiceActive }

    mutating func append(_ buffer: [Float], sensitivity: Double) {
        guard !isComplete, !buffer.isEmpty else { return }
        let squareSum = buffer.reduce(0.0) { $0 + Double($1) * Double($1) }
        let rms = sqrt(squareSum / Double(buffer.count))
        let power = 20 * log10(max(1e-8, rms))
        level = min(1, rms * 7)
        elapsed += Double(buffer.count) / Double(Self.sampleRate)
        samples.append(contentsOf: buffer)
        switch detector.observe(power: power, elapsed: elapsed, sensitivity: sensitivity) {
        case .endOfSpeech:
            isComplete = true
        case .noSpeech:
            // Silence does not end the conversation or require another button.
            detector = NAVAVoiceActivityDetector()
            elapsed = 0
        case .listening:
            break
        }
        let limit = Self.sampleRate * (hasSpeech ? 29 : 3)
        if samples.count > limit { samples.removeFirst(samples.count - limit) }
    }
}
