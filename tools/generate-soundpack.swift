import Foundation

// Three original, offline, playable ambient loops. Generated, not padding.
struct Atmosphere {
    let name: String
    let notes: [Double]
    let seed: UInt64
    let air: Double
}
let tracks = [
    Atmosphere(name: "EmberRain", notes: [55, 82.41, 110], seed: 1001, air: 0.28),
    Atmosphere(name: "StillSpace", notes: [65.41, 98, 130.81], seed: 2001, air: 0.18),
    Atmosphere(name: "NightDrive", notes: [73.42, 110, 146.83], seed: 3001, air: 0.24)
]
let folder = URL(fileURLWithPath: "NAVA/Resources/Sounds", isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let sampleRate = 22_050, seconds = 60
let frames = sampleRate * seconds
func putLE<T: FixedWidthInteger>(_ value: T, _ bytes: inout Data) {
    var v = value.littleEndian
    withUnsafeBytes(of: &v) { bytes.append(contentsOf: $0) }
}
for track in tracks {
    var pcm = [Int16](repeating: 0, count: frames * 2)
    var state = track.seed
    var smoothL = 0.0, smoothR = 0.0
    for frame in 0..<frames {
        let time = Double(frame) / Double(sampleRate)
        let envelope = min(1.0, max(0.0, time / 1.3), max(0.0, (Double(seconds) - time) / 1.3))
        state = state &* 2862933555777941757 &+ 3037000493
        let noiseL = Double((state >> 32) & 0xFFFF) / 32767.5 - 1
        state = state &* 2862933555777941757 &+ 3037000493
        let noiseR = Double((state >> 32) & 0xFFFF) / 32767.5 - 1
        smoothL = 0.83 * smoothL + 0.17 * noiseL
        smoothR = 0.83 * smoothR + 0.17 * noiseR
        var pad = 0.0
        for (i, note) in track.notes.enumerated() {
            pad += sin(2 * Double.pi * note * time + Double(i) * 1.6) * 0.23 / Double(i + 1)
        }
        let left = envelope * (pad * (0.75 + 0.13 * sin(time * 0.4)) + smoothL * track.air * 0.4)
        let right = envelope * (pad * (0.72 + 0.14 * sin(time * 0.27)) + smoothR * track.air * 0.4)
        pcm[frame * 2] = Int16(max(-1.0, min(1.0, left)) * 32767)
        pcm[frame * 2 + 1] = Int16(max(-1.0, min(1.0, right)) * 32767)
    }
    var wave = Data()
    let size = UInt32(pcm.count * 2)
    wave.append(contentsOf: "RIFF".utf8)
    putLE(size + 36, &wave)
    wave.append(contentsOf: "WAVEfmt ".utf8)
    putLE(UInt32(16), &wave)
    putLE(UInt16(1), &wave)
    putLE(UInt16(2), &wave)
    putLE(UInt32(sampleRate), &wave)
    putLE(UInt32(sampleRate * 4), &wave)
    putLE(UInt16(4), &wave)
    putLE(UInt16(16), &wave)
    wave.append(contentsOf: "data".utf8)
    putLE(size, &wave)
    pcm.withUnsafeBytes { wave.append(contentsOf: $0) }
    let file = folder.appendingPathComponent(track.name + ".wav")
    try wave.write(to: file, options: .atomic)
    print("\(track.name): \(wave.count) bytes")
}
