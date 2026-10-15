import Foundation

@main
struct VoiceActivityDetectorTests {
    static func main() {
        func feed(_ detector: inout NAVAVoiceActivityDetector, power: Double,
                  from start: Double, through end: Double) -> NAVAVoiceActivityDetector.Decision {
            var result = NAVAVoiceActivityDetector.Decision.listening
            for time in stride(from: start, through: end, by: 0.12) {
                result = detector.observe(power: power, elapsed: time, sensitivity: 0.16)
                if result != .listening { return result }
            }
            return result
        }
        var quiet = NAVAVoiceActivityDetector()
        assert(feed(&quiet, power: -65, from: 0, through: 0.36) == .listening)
        // Quiet speech (-40 dB) fell below the previous normalized 0.16 gate.
        assert(feed(&quiet, power: -40, from: 0.48, through: 2) == .listening)
        assert(quiet.heardSpeech)
        assert(feed(&quiet, power: -65, from: 2.04, through: 3) == .listening)
        assert(feed(&quiet, power: -65, from: 3.12, through: 4) == .endOfSpeech)

        var noise = NAVAVoiceActivityDetector()
        assert(feed(&noise, power: -32, from: 0, through: 34.9) == .listening)
        assert(!noise.heardSpeech)
        assert(feed(&noise, power: -32, from: 35, through: 36) == .noSpeech)

        var click = NAVAVoiceActivityDetector()
        _ = feed(&click, power: -65, from: 0, through: 0.36)
        _ = click.observe(power: -15, elapsed: 0.6, sensitivity: 0.16)
        _ = feed(&click, power: -65, from: 0.72, through: 2)
        assert(!click.heardSpeech)

        var longSpeech = NAVAVoiceActivityDetector()
        _ = feed(&longSpeech, power: -65, from: 0, through: 0.36)
        assert(feed(&longSpeech, power: -25, from: 0.48, through: 28) == .endOfSpeech)
        print("Voice activity detector checks passed")
    }
}
