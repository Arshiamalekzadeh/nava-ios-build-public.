import AVFoundation
import Combine
import Foundation

struct NAVAVoiceMemo: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    let filename: String
    let createdAt: Date
    let duration: TimeInterval
    var transcript: String?
}

enum NAVAVoiceMemoError: LocalizedError {
    case microphoneDenied
    case cannotStart
    case missingRecording

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: "اجازه میکروفون برای NAVA فعال نیست. از تنظیمات آیفون فعالش کن."
        case .cannotStart: "ضبط صدا شروع نشد. دوباره امتحان کن."
        case .missingRecording: "فایل ضبط‌شده در حافظه آیفون پیدا نشد."
        }
    }
}

/// Local M4A recorder. No voice is uploaded to a server. Works independently
/// from Apple's Persian speech recognition support.
@MainActor
final class NAVAVoiceMemoStore: ObservableObject {
    @Published private(set) var memos: [NAVAVoiceMemo] = []
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var level: CGFloat = 0
    @Published private(set) var playingID: UUID?
    @Published var errorMessage: String?

    private let storageKey = "nava.voice.memos.v4"
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var ticker: Timer?
    private var startedAt: Date?
    private var pendingURL: URL?

    private var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NAVARecordings", isDirectory: true)
    }

    init() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([NAVAVoiceMemo].self, from: data) {
            memos = decoded.filter { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0.filename).path) }
        }
    }

    func url(for memo: NAVAVoiceMemo) -> URL {
        directory.appendingPathComponent(memo.filename, isDirectory: false)
    }

    func start() async throws {
        guard !isRecording else { return }
        errorMessage = nil
        let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard granted else {
            errorMessage = NAVAVoiceMemoError.microphoneDenied.localizedDescription
            throw NAVAVoiceMemoError.microphoneDenied
        }
        stopPlayback()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            let path = directory.appendingPathComponent(UUID().uuidString + ".m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 24000,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 48000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let newRecorder = try AVAudioRecorder(url: path, settings: settings)
            newRecorder.isMeteringEnabled = true
            guard newRecorder.prepareToRecord(), newRecorder.record() else {
                throw NAVAVoiceMemoError.cannotStart
            }
            pendingURL = path
            recorder = newRecorder
            startedAt = Date()
            elapsed = 0
            level = 0
            isRecording = true
            startMetering()
        } catch {
            isRecording = false
            recorder?.stop()
            recorder = nil
            if let pendingURL { try? FileManager.default.removeItem(at: pendingURL) }
            pendingURL = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            errorMessage = error.localizedDescription
            throw error
        }
    }

    @discardableResult
    func stop(save: Bool = true) -> NAVAVoiceMemo? {
        guard isRecording, let recorder else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        ticker?.invalidate()
        ticker = nil
        self.recorder = nil
        isRecording = false
        elapsed = 0
        level = 0
        defer {
            pendingURL = nil
            startedAt = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        guard let url = pendingURL else { return nil }
        guard save, duration > 0.25,
              FileManager.default.fileExists(atPath: url.path) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        let memo = NAVAVoiceMemo(
            id: UUID(),
            title: "ضبط \(Date().formatted(.dateTime.day().month().hour().minute()))",
            filename: url.lastPathComponent,
            createdAt: startedAt ?? Date(),
            duration: duration,
            transcript: nil
        )
        memos.insert(memo, at: 0)
        persist()
        return memo
    }

    func togglePlayback(_ memo: NAVAVoiceMemo) {
        if playingID == memo.id {
            stopPlayback()
            return
        }
        guard !isRecording else { return }
        stopPlayback()
        do {
            let audioURL = url(for: memo)
            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                throw NAVAVoiceMemoError.missingRecording
            }
            let player = try AVAudioPlayer(contentsOf: audioURL)
            self.player = player
            player.prepareToPlay()
            guard player.play() else { throw NAVAVoiceMemoError.cannotStart }
            playingID = memo.id
            startMetering()
        } catch {
            errorMessage = error.localizedDescription
            playingID = nil
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        playingID = nil
        if !isRecording {
            ticker?.invalidate()
            ticker = nil
        }
    }

    func rename(_ memo: NAVAVoiceMemo, to name: String) {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        memos[index].title = trimmed
        persist()
    }

    func updateTranscript(id: UUID, text: String) {
        guard let index = memos.firstIndex(where: { $0.id == id }) else { return }
        memos[index].transcript = text
        persist()
    }

    func delete(_ memo: NAVAVoiceMemo) {
        if playingID == memo.id { stopPlayback() }
        try? FileManager.default.removeItem(at: url(for: memo))
        memos.removeAll { $0.id == memo.id }
        persist()
    }

    func deleteAll() {
        stopPlayback()
        if isRecording { _ = stop(save: false) }
        for memo in memos { try? FileManager.default.removeItem(at: url(for: memo)) }
        memos = []
        persist()
    }

    private func startMetering() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let recorder = self.recorder, self.isRecording {
                    recorder.updateMeters()
                    let power = recorder.averagePower(forChannel: 0)
                    self.level = max(0.06, min(1, CGFloat(pow(10, power / 35))))
                    self.elapsed = recorder.currentTime
                } else if let player = self.player, !player.isPlaying {
                    self.stopPlayback()
                }
            }
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(memos) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
