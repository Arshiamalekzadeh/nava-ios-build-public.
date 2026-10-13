import Combine
import Foundation
import Security

enum NAVATranscriptionError: LocalizedError {
    case notConfigured
    case insecureURL
    case invalidFile
    case invalidResponse
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "اول در تنظیمات نوا آدرس سرویس تبدیل صدا به متن رو مشخص کن."
        case .insecureURL: "برای محافظت از صدای تو، فقط آدرس HTTPS قابل‌استفاده است."
        case .invalidFile: "این فایل صوتی پیدا نشد یا حجمش از سقف ۲۵ مگابایت بیشتره."
        case .invalidResponse: "سرویس تبدیل صدا پاسخ قابل‌خواندن نداد."
        case .server(let code, let description): "خطای سرویس (\(code)): \(description)"
        }
    }
}

/// Optional BYO transcription endpoint; not included in ChatGPT Plus.
/// Credentials never leave Keychain, and recorded audio is sent only on
/// a deliberate user tap to the configured HTTPS URL.
@MainActor
final class NAVATranscriptionService: ObservableObject {
    @Published var endpoint: String
    @Published var model: String
    @Published var secret: String
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private let endpointKey = "nava.transcription.url.v4"
    private let modelKey = "nava.transcription.model.v4"
    private let serviceName = "com.arshia.nava.transcription"
    private let accountName = "optional-api-key"

    init() {
        endpoint = UserDefaults.standard.string(forKey: endpointKey) ?? "https://api.openai.com/v1/audio/transcriptions"
        model = UserDefaults.standard.string(forKey: modelKey) ?? "gpt-4o-mini-transcribe"
        secret = Self.readSecret(service: serviceName, account: accountName) ?? ""
    }

    var configured: Bool {
        guard let url = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host != nil else { return false }
        return !secret.isEmpty || url.host != "api.openai.com"
    }

    func saveSettings() throws {
        let trimmedURL = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL), url.scheme == "https",
              url.host != nil else { throw NAVATranscriptionError.insecureURL }
        UserDefaults.standard.set(url.absoluteString, forKey: endpointKey)
        UserDefaults.standard.set(model.trimmingCharacters(in: .whitespacesAndNewlines), forKey: modelKey)
        let key: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        SecItemDelete(key as CFDictionary)
        if !secret.isEmpty {
            var update = key
            update[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            update[kSecValueData as String] = Data(secret.utf8)
            guard SecItemAdd(update as CFDictionary, nil) == errSecSuccess else {
                throw NAVATranscriptionError.notConfigured
            }
        }
    }

    func transcribe(file: URL) async throws -> String {
        guard !isWorking else { throw NAVATranscriptionError.invalidResponse }
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil

        let address = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: address), url.scheme == "https", url.host != nil else {
            throw NAVATranscriptionError.insecureURL
        }
        let fileData = try Data(contentsOf: file)
        guard !fileData.isEmpty, fileData.count <= 25 * 1024 * 1024 else {
            throw NAVATranscriptionError.invalidFile
        }
        let boundary = "NAVA-\(UUID().uuidString)"
        var body = Data()
        func addField(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        addField("model", model.trimmingCharacters(in: .whitespacesAndNewlines))
        addField("language", "fa")
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"nava-speech.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n".utf8))
        body.append(fileData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if !secret.isEmpty {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        let (responseBytes, response) = try await URLSession.shared.data(for: request)
        guard let code = (response as? HTTPURLResponse)?.statusCode else {
            throw NAVATranscriptionError.invalidResponse
        }
        if !(200..<300).contains(code) {
            let description = String(data: responseBytes.prefix(500), encoding: .utf8) ?? "Unknown error"
            throw NAVATranscriptionError.server(code, description)
        }
        guard let json = try? JSONSerialization.jsonObject(with: responseBytes) as? [String: Any],
              let text = json["text"] as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NAVATranscriptionError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func readSecret(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
