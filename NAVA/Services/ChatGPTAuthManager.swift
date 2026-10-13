import Foundation
import Combine
import Security

struct ChatGPTLoginBrowser: Identifiable {
    let id = UUID()
    let url: URL
}

struct ChatGPTCredentials: Codable {
    let subject: String
    let email: String?
    let clientID: String
    let hostID: String
    let accessToken: String
    let refreshToken: String?
    let idToken: String
    let scopes: [String]
    let expiresAt: Date

    var planEnabled: Bool {
        scopes.contains("chatgpt.tokens.use.direct") && scopes.contains("resource.invoke")
    }
}

enum ChatGPTAuthError: LocalizedError {
    case invalidState, invalidRegistration, denied, invalidIDToken, identityMismatch
    case invalidResponse, failedRequest(Int), missingRefresh, notConnected, permissionMissing

    var errorDescription: String? {
        switch self {
        case .invalidState: "درخواست ورود قابل تأیید نیست؛ دوباره تلاش کن."
        case .invalidRegistration: "ثبت اپ در OpenAI کامل نشد. ورود رو دوباره شروع کن."
        case .denied: "اجازه ورود یا دسترسی به طرح ChatGPT تأیید نشد."
        case .invalidIDToken: "هویت حساب ChatGPT قابل اعتبارسنجی نیست."
        case .identityMismatch: "حساب بازگشتی با حساب انتخاب‌شده مطابقت ندارد."
        case .invalidResponse: "پاسخ احراز هویت OpenAI معتبر نیست."
        case .failedRequest(let status): "OpenAI درخواست رو با کد \(status) رد کرد."
        case .missingRefresh: "نشست منقضی شده؛ دوباره وارد ChatGPT شو."
        case .notConnected: "ابتدا با حساب ChatGPT وارد شو."
        case .permissionMissing: "ورود انجام شد، اما اجازه استفاده از طرح ChatGPT داده نشده."
        }
    }
}

private struct OAuthTokenPayload: Decodable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let scope: String?
    let tokenType: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case scope
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

private enum NAVACredentialsKeychain {
    private static let service = "com.arshia.nava.chatgpt"
    private static let account = "current"

    static func load() -> ChatGPTCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(ChatGPTCredentials.self, from: data)
    }

    static func save(_ credentials: ChatGPTCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        clear()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw ChatGPTAuthError.invalidResponse
        }
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
final class ChatGPTAuthManager: ObservableObject {
    @Published private(set) var credentials: ChatGPTCredentials?
    @Published private(set) var isSigningIn = false
    @Published private(set) var message = ""
    @Published var errorMessage: String?
    @Published var browser: ChatGPTLoginBrowser?

    private var server: OAuthLoopbackServer?
    private var pending: ChatGPTOAuth.Attempt?
    private var returning: ChatGPTCredentials?
    private var waitingForBrowser = false
    private var refreshTask: Task<String, Error>?
    private let hostID: String

    init() {
        let key = "nava.chatgpt.host-id"
        if let existing = UserDefaults.standard.string(forKey: key), existing.hasPrefix("urn:uuid:") {
            hostID = existing
        } else {
            let generated = "urn:uuid:\(UUID().uuidString.lowercased())"
            hostID = generated
            UserDefaults.standard.set(generated, forKey: key)
        }
        credentials = NAVACredentialsKeychain.load()
    }

    var isConnected: Bool { credentials != nil }
    var canUsePlan: Bool { credentials?.planEnabled == true }

    func signIn(newAccount: Bool = false) async {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        message = "در حال آماده‌سازی ورود امن…"
        returning = newAccount ? nil : credentials
        let listener = OAuthLoopbackServer { [weak self] url in
            Task { @MainActor [weak self] in
                await self?.handleCallback(url)
            }
        }
        server = listener
        do {
            let port = try await listener.start()
            guard isSigningIn else { listener.stop(); return }
            let attempt = ChatGPTOAuth.createAttempt(
                port: port,
                hostID: hostID,
                registeredClientID: returning?.clientID,
                idTokenHint: returning?.idToken,
                loginHint: returning?.email
            )
            pending = attempt
            waitingForBrowser = true
            message = "صفحه رسمی ورود ChatGPT باز شده."
            browser = ChatGPTLoginBrowser(url: attempt.url)
        } catch {
            fail(error)
        }
    }

    func cancelIfBrowserDismissed() {
        if waitingForBrowser { cancel() }
    }

    func cancel() {
        guard isSigningIn else { return }
        waitingForBrowser = false
        isSigningIn = false
        pending = nil
        returning = nil
        browser = nil
        server?.stop()
        server = nil
        message = "ورود لغو شد."
    }

    private func handleCallback(_ url: URL) async {
        guard waitingForBrowser, let attempt = pending else { return }
        waitingForBrowser = false
        browser = nil
        server?.stop()
        server = nil
        message = "در حال بررسی و تأیید حساب ChatGPT…"

        do {
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            func parameter(_ key: String) -> String? {
                query.first(where: { $0.name == key })?.value
            }
            guard url.scheme == "http", url.host == "127.0.0.1",
                  url.path == "/auth/callback",
                  url.absoluteString.hasPrefix(attempt.redirectURI + "?"),
                  parameter("state") == attempt.state else { throw ChatGPTAuthError.invalidState }
            if parameter("error") != nil { throw ChatGPTAuthError.denied }
            guard let code = parameter("code"), !code.isEmpty else { throw ChatGPTAuthError.invalidResponse }
            let issuedClientID: String
            if let returning {
                if let returnedID = parameter("client_id"), returnedID != returning.clientID {
                    throw ChatGPTAuthError.invalidRegistration
                }
                issuedClientID = returning.clientID
            } else {
                guard let returnedID = parameter("client_id"),
                      returnedID.hasPrefix("oaiapp_") else { throw ChatGPTAuthError.invalidRegistration }
                issuedClientID = returnedID
            }
            let tokens = try await requestToken([
                "grant_type": "authorization_code",
                "client_id": issuedClientID,
                "code": code,
                "code_verifier": attempt.verifier,
                "redirect_uri": attempt.redirectURI,
                "resource": ChatGPTOAuth.resource
            ])
            guard let idToken = tokens.idToken,
                  !tokens.accessToken.isEmpty else { throw ChatGPTAuthError.invalidResponse }
            let identity = try await ChatGPTIDTokenValidator.validate(
                idToken, clientID: issuedClientID, nonce: attempt.nonce
            )
            if let returning, returning.subject != identity.subject {
                throw ChatGPTAuthError.identityMismatch
            }
            let newCredentials = ChatGPTCredentials(
                subject: identity.subject,
                email: identity.email,
                clientID: issuedClientID,
                hostID: hostID,
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                idToken: idToken,
                scopes: tokens.scope?.split(separator: " ").map(String.init) ?? [],
                expiresAt: Date().addingTimeInterval(TimeInterval(tokens.expiresIn ?? 3600))
            )
            try NAVACredentialsKeychain.save(newCredentials)
            credentials = newCredentials
            message = newCredentials.planEnabled ? "حساب ChatGPT متصل شد ✓" :
                "ورود انجام شد؛ استفاده از سهمیه Plus هنوز تأیید نشده."
            errorMessage = nil
            finish()
        } catch {
            fail(error)
        }
    }

    func accessTokenForPlan() async throws -> String {
        guard let credentials else { throw ChatGPTAuthError.notConnected }
        guard credentials.planEnabled else { throw ChatGPTAuthError.permissionMissing }
        if credentials.expiresAt > Date().addingTimeInterval(120) { return credentials.accessToken }
        if let refreshTask { return try await refreshTask.value }
        let task = Task<String, Error> { try await self.refresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func refresh() async throws -> String {
        guard let old = credentials, let refreshToken = old.refreshToken else {
            throw ChatGPTAuthError.missingRefresh
        }
        let tokens = try await requestToken([
            "grant_type": "refresh_token",
            "client_id": old.clientID,
            "refresh_token": refreshToken,
            "resource": ChatGPTOAuth.resource
        ])
        let updated = ChatGPTCredentials(
            subject: old.subject, email: old.email, clientID: old.clientID, hostID: old.hostID,
            accessToken: tokens.accessToken, refreshToken: tokens.refreshToken ?? old.refreshToken,
            idToken: old.idToken, // Do not persist an unvalidated replacement ID token from refresh.
            scopes: tokens.scope?.split(separator: " ").map(String.init) ?? old.scopes,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokens.expiresIn ?? 3600))
        )
        guard updated.planEnabled else { throw ChatGPTAuthError.permissionMissing }
        try NAVACredentialsKeychain.save(updated)
        credentials = updated
        return updated.accessToken
    }

    func signOut() async {
        cancel()
        let old = credentials
        credentials = nil
        NAVACredentialsKeychain.clear()
        message = "از حساب ChatGPT خارج شدی."
        guard let old, let refreshToken = old.refreshToken else { return }
        do {
            let configURL = URL(string: "https://auth.openai.com/.well-known/openid-configuration")!
            let (data, response) = try await URLSession.shared.data(from: configURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let config = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let endpoint = config["revocation_endpoint"] as? String,
                  let url = URL(string: endpoint), url.scheme == "https",
                  url.host == "auth.openai.com" else { throw ChatGPTAuthError.invalidResponse }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = formBody([
                "token": refreshToken, "token_type_hint": "refresh_token", "client_id": old.clientID
            ])
            let (_, revokeResponse) = try await URLSession.shared.data(for: request)
            guard (revokeResponse as? HTTPURLResponse)?.statusCode == 200 else {
                throw ChatGPTAuthError.invalidResponse
            }
        } catch {
            errorMessage = "از دستگاه خارج شدی؛ لغو نشست در سرور تأیید نشد. دسترسی NAVA را از تنظیمات ChatGPT هم می‌توانی قطع کنی."
        }
    }

    private func requestToken(_ values: [String: String]) async throws -> OAuthTokenPayload {
        var request = URLRequest(url: ChatGPTOAuth.tokenEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody(values)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else {
            throw ChatGPTAuthError.invalidResponse
        }
        guard (200..<300).contains(status) else { throw ChatGPTAuthError.failedRequest(status) }
        let result = try JSONDecoder().decode(OAuthTokenPayload.self, from: data)
        if let type = result.tokenType, type.lowercased() != "bearer" {
            throw ChatGPTAuthError.invalidResponse
        }
        return result
    }

    private func formBody(_ values: [String: String]) -> Data {
        var pieces = URLComponents()
        pieces.queryItems = values.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return Data((pieces.percentEncodedQuery ?? "").replacingOccurrences(of: "%20", with: "+").utf8)
    }

    private func finish() {
        isSigningIn = false
        pending = nil
        returning = nil
        waitingForBrowser = false
    }

    private func fail(_ error: Error) {
        errorMessage = error.localizedDescription
        message = "ورود کامل نشد."
        browser = nil
        server?.stop()
        server = nil
        finish()
    }
}
