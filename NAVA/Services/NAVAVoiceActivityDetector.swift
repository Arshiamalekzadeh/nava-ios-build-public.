import Foundation

/// End-of-turn detection uses microphone decibels, independently of the UI meter.
struct NAVAVoiceActivityDetector {
    enum Decision: Equatable { case listening, endOfSpeech, noSpeech }

    private(set) var heardSpeech = false
    private(set) var isVoiceActive = false
    private var noiseFloor: Double = -60
    private var calibrationFloor: Double?
    private var speechFrames = 0
    private var lastSpeechAt: TimeInterval = 0
    private var speechStartedAt: TimeInterval?

    mutating func observe(power: Double, elapsed: TimeInterval, sensitivity: Double) -> Decision {
        guard elapsed >= 0, power.isFinite else { return .listening }
        // Calibrate from the initial microphone settling period. A noisy room
        // should not be mistaken for one continuous spoken command.
        if elapsed < 0.4 {
            isVoiceActive = false
            // A loud first syllable must not become the ambient-noise floor.
            // Use the quietest settling frame rather than the latest frame.
            let candidate = max(-70, min(-20, power))
            calibrationFloor = min(calibrationFloor ?? candidate, candidate)
            noiseFloor = calibrationFloor ?? candidate
            return .listening
        }
        let margin = 6 + (min(0.25, max(0.10, sensitivity)) - 0.10) * 40
        let threshold = max(-55, noiseFloor + margin)
        let isSpeech = power >= threshold - (heardSpeech ? 3 : 0)
        isVoiceActive = isSpeech
        if isSpeech {
            speechFrames += 1
            if speechFrames >= 2 {
                if !heardSpeech { speechStartedAt = elapsed }
                heardSpeech = true
                lastSpeechAt = elapsed
            }
        } else {
            speechFrames = 0
            // Track quieter ambient sound without learning the speaker's voice.
            noiseFloor = 0.95 * noiseFloor + 0.05 * power
        }
        if heardSpeech, elapsed - lastSpeechAt >= 1.45 { return .endOfSpeech }
        if let speechStartedAt, elapsed - speechStartedAt >= 26 { return .endOfSpeech }
        if !heardSpeech, elapsed >= 35 { return .noSpeech }
        return .listening
    }
}
