import Foundation
import CryptoKit
import Security

/// Official OSS ChatGPT authorization preparation.
/// Never treats an authorization URL as a successful login.
enum ChatGPTOAuth {
    static let authorizationEndpoint = URL(string: "https://auth.openai.com/api/accounts/authorize")!
    static let tokenEndpoint = URL(string: "https://auth.openai.com/api/accounts/oauth/token")!
    static let resource = "https://api.openai.com/v1"
    static let scopes = "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct"

    struct Attempt {
        let verifier: String
        let state: String
        let nonce: String
        let hostID: String
        let redirectURI: String
        let url: URL
    }

    static func createAttempt(port: UInt16, hostID: String, registeredClientID: String? = nil, idTokenHint: String? = nil, loginHint: String? = nil) -> Attempt {
        let verifier = randomURLSafe(32)
        let state = randomURLSafe(32)
        let nonce = randomURLSafe(32)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8)))
            .base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let callback = "http://127.0.0.1:\(port)/auth/callback"
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)!
        var params: [URLQueryItem] = [
            .init(name: "client_id", value: registeredClientID ?? "dynamic_agent_client"),
            .init(name: "ext_agent_host_id", value: hostID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: callback),
            .init(name: "scope", value: scopes),
            .init(name: "resource", value: resource),
            .init(name: "state", value: state),
            .init(name: "nonce", value: nonce),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge)
        ]
        if registeredClientID == nil {
            params.append(.init(name: "agent_name_hint", value: "NAVA"))
        }
        if let idTokenHint, registeredClientID != nil {
            params.append(.init(name: "id_token_hint", value: idTokenHint))
        }
        if let loginHint, registeredClientID != nil {
            params.append(.init(name: "login_hint", value: loginHint))
        }
        components.queryItems = params
        return Attempt(verifier: verifier, state: state, nonce: nonce, hostID: hostID, redirectURI: callback, url: components.url!)
    }

    private static func randomURLSafe(_ count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(result == errSecSuccess)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

