import Combine
import Foundation
import WhisperKit

/// Speech-to-text that runs on the iPhone with an openly licensed Whisper
/// model. Does not use Apple's SFSpeechRecognizer or a ChatGPT Plus session.
///
/// WhisperKit downloads the selected Core ML model from its model repository
/// when the user explicitly chooses to prepare it. Subsequent transcription
/// reuses the cached model and runs without an API key.
@MainActor
final class NAVAOfflineSpeechService: ObservableObject {
    @Published private(set) var isPreparing = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var phase = "مدل فارسی هنوز فعال نشده"
    @Published var errorMessage: String?

    private var engine: WhisperKit?
    private var engineVariant: String?
    private let cachedPrefix = "nava.whisper.model.prepared."

    init() {
        if UserDefaults.standard.bool(forKey: "nava.whisper.model.prepared.tiny") ||
           UserDefaults.standard.bool(forKey: "nava.whisper.model.prepared.base") {
            phase = "مدل قبلاً دانلود شده؛ آماده بارگذاری روی آیفون"
        }
    }

    func wasPrepared(_ name: String) -> Bool {
        UserDefaults.standard.bool(forKey: cachedPrefix + normalized(name))
    }

    /// Preparing may download a substantial model. Call only after the
    /// user confirms that a download is acceptable.
    func prepare(model name: String) async throws {
        let variant = normalized(name)
        if engine != nil && engineVariant == variant { return }
        guard !isPreparing && !isTranscribing else {
            throw NAVAOfflineSpeechError.busy
        }
        isPreparing = true
        errorMessage = nil
        phase = wasPrepared(variant)
            ? "در حال بارگذاری مدل فارسی روی آیفون…"
            : "در حال دانلود مدل فارسی؛ ممکنه چند دقیقه طول بکشه…"
        defer { isPreparing = false }

        do {
            engine = nil
            engineVariant = nil
            // Explicit model selection avoids defaulting to the very large
            // device-recommended model. Both variants are multilingual.
            let pipeline = try await WhisperKit(
                WhisperKitConfig(model: variant, verbose: false, load: true, download: true)
            )
            engine = pipeline
            engineVariant = variant
            UserDefaults.standard.set(true, forKey: cachedPrefix + variant)
            phase = "مدل \(variant == "base" ? "دقیق‌تر" : "سبک") آماده است · پردازش روی آیفون"
        } catch {
            let reason = "مدل آفلاین آماده نشد: \(error.localizedDescription)"
            errorMessage = reason
            phase = "آماده‌سازی ناموفق"
            throw NAVAOfflineSpeechError.preparation(reason)
        }
    }

    /// Only audio files the user has actually recorded are accepted.
    /// The result is always a text transcript, never a fictional success.
    func transcribe(file: URL, model name: String) async throws -> String {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw NAVAOfflineSpeechError.missingAudio
        }
        if engine == nil || engineVariant != normalized(name) {
            try await prepare(model: name)
        }
        guard let pipeline = engine, !isTranscribing else {
            throw NAVAOfflineSpeechError.busy
        }

        isTranscribing = true
        phase = "در حال تشخیص گفتار فارسی، بدون ارسال صدا…"
        defer {
            isTranscribing = false
            if engine != nil {
                phase = "مدل فارسی آماده است · بدون نیاز به Apple Speech"
            }
        }

        do {
            let options = DecodingOptions(task: .transcribe, language: "fa")
            let results = try await pipeline.transcribe(
                audioPath: file.path,
                decodeOptions: options
            )
            let transcript = results.map(\.text)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !transcript.isEmpty else {
                throw NAVAOfflineSpeechError.noRecognizedWords
            }
            errorMessage = nil
            return transcript
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func normalized(_ value: String) -> String {
        value == "base" ? "base" : "tiny"
    }
}

enum NAVAOfflineSpeechError: LocalizedError {
    case busy
    case missingAudio
    case noRecognizedWords
    case preparation(String)

    var errorDescription: String? {
        switch self {
        case .busy: "مدل هنوز مشغول پردازش صداست. کمی صبر کن."
        case .missingAudio: "فایل ضبط صدا پیدا نشد."
        case .noRecognizedWords: "صدای قابل‌تشخیصی پیدا نشد. دوباره و نزدیک‌تر به میکروفون بگو."
        case .preparation(let message): message
        }
    }
}
