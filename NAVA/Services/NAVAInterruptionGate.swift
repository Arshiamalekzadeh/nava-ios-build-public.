import Foundation

/// A click or a brief residual echo must not cancel a reply. Fire only once
/// after sustained voiced input; hardware echo cancellation runs before this.
struct NAVAInterruptionGate {
    private var voiceStartedAt: TimeInterval?
    private var fired = false

    mutating func observe(isVoiceActive: Bool, at time: TimeInterval) -> Bool {
        guard !fired, time.isFinite else { return false }
        guard isVoiceActive else {
            voiceStartedAt = nil
            return false
        }
        guard let start = voiceStartedAt else {
            voiceStartedAt = time
            return false
        }
        guard time - start >= 0.24 else { return false }
        fired = true
        return true
    }
}
