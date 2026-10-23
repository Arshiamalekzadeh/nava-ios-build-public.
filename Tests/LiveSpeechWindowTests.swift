import Foundation

@main
struct LiveSpeechWindowTests {
    static func main() {
        func feed(_ window: inout NAVALiveSpeechWindow, power: Double, seconds: Double) {
            let amplitude = Float(pow(10, power / 20))
            let buffer = [Float](repeating: amplitude, count: 1_600)
            for _ in 0..<Int(seconds * 10) { window.append(buffer, sensitivity: 0.16) }
        }
        var turn = NAVALiveSpeechWindow()
        feed(&turn, power: -65, seconds: 0.4)
        feed(&turn, power: -38, seconds: 2)
        assert(turn.hasSpeech && !turn.isComplete)
        assert(turn.samples.count >= 32_000, "Samples are available before the turn ends")
        feed(&turn, power: -65, seconds: 0.8)
        assert(!turn.isComplete, "A short pause must not submit a partial sentence")
        feed(&turn, power: -38, seconds: 1)
        feed(&turn, power: -65, seconds: 1.8)
        assert(turn.isComplete, "A completed turn needs no send button")
        let finalCount = turn.samples.count
        feed(&turn, power: -20, seconds: 1)
        assert(turn.samples.count == finalCount, "Final input is frozen while decoding")

        var idle = NAVALiveSpeechWindow()
        feed(&idle, power: -65, seconds: 180)
        assert(!idle.isComplete && !idle.hasSpeech, "Silence keeps the session available")
        assert(idle.samples.count <= NAVALiveSpeechWindow.sampleRate * 3, "Idle buffers remain bounded")
        feed(&idle, power: -35, seconds: 2)
        feed(&idle, power: -65, seconds: 2)
        assert(idle.isComplete, "Speech after a long wait still submits automatically")

        var next = NAVALiveSpeechWindow()
        assert(next.samples.isEmpty && !next.isComplete)
        feed(&next, power: -65, seconds: 0.4)
        feed(&next, power: -35, seconds: 30)
        assert(next.isComplete, "Long speech is capped without unbounded memory")
        assert(next.samples.count <= NAVALiveSpeechWindow.sampleRate * 29)
        print("Live speech window checks passed")
    }
}
