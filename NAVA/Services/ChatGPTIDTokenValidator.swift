import Foundation
import Security

struct ChatGPTValidatedIdentity {
    let subject: String
    let email: String?
}

/// OIDC RS256 signature and claims validation. No identity is accepted based
/// solely on decoding a JWT payload.
enum ChatGPTIDTokenValidator {
    static func validate(_ token: String, clientID: String, nonce: String) async throws -> ChatGPTValidatedIdentity {
        let pieces = token.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 3,
              let headerData = decode(String(pieces[0])),
              let payloadData = decode(String(pieces[1])),
              let signature = decode(String(pieces[2])),
              let header = try JSONSerialization.jsonObject(with: headerData) as? [String: Any],
              let claims = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              header["alg"] as? String == "RS256",
              let kid = header["kid"] as? String,
              !kid.isEmpty else { throw ChatGPTAuthError.invalidIDToken }

        let discoveryURL = URL(string: "https://auth.openai.com/.well-known/openid-configuration")!
        let (discoveryBytes, discoveryResponse) = try await URLSession.shared.data(from: discoveryURL)
        guard (discoveryResponse as? HTTPURLResponse)?.statusCode == 200,
              let discovery = try JSONSerialization.jsonObject(with: discoveryBytes) as? [String: Any],
              discovery["issuer"] as? String == "https://auth.openai.com",
              let jwksString = discovery["jwks_uri"] as? String,
              let jwksURL = URL(string: jwksString),
              jwksURL.scheme == "https",
              jwksURL.host == "auth.openai.com" else { throw ChatGPTAuthError.invalidIDToken }

        let (jwksBytes, jwksResponse) = try await URLSession.shared.data(from: jwksURL)
        guard (jwksResponse as? HTTPURLResponse)?.statusCode == 200,
              let jwks = try JSONSerialization.jsonObject(with: jwksBytes) as? [String: Any],
              let keys = jwks["keys"] as? [[String: Any]],
              let keyInfo = keys.first(where: {
                  $0["kid"] as? String == kid && $0["kty"] as? String == "RSA" &&
                  ($0["alg"] as? String == nil || $0["alg"] as? String == "RS256")
              }),
              let n = keyInfo["n"] as? String, let e = keyInfo["e"] as? String,
              let modulus = decode(n), let exponent = decode(e),
              !modulus.isEmpty, !exponent.isEmpty
        else { throw ChatGPTAuthError.invalidIDToken }

        let rsaBytes = sequence(integer(modulus) + integer(exponent))
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits: modulus.count * 8
        ]
        var keyError: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(Data(rsaBytes) as CFData, attributes as CFDictionary, &keyError) else {
            throw ChatGPTAuthError.invalidIDToken
        }
        let signedMessage = Data("\(pieces[0]).\(pieces[1])".utf8)
        guard SecKeyVerifySignature(publicKey, .rsaSignatureMessagePKCS1v15SHA256,
                                    signedMessage as CFData, signature as CFData, &keyError) else {
            throw ChatGPTAuthError.invalidIDToken
        }

        let now = Date().timeIntervalSince1970
        let expiration = (claims["exp"] as? NSNumber)?.doubleValue ?? 0
        let notBefore = (claims["nbf"] as? NSNumber)?.doubleValue ?? 0
        let issuedAt = (claims["iat"] as? NSNumber)?.doubleValue ?? 0
        let audience = claims["aud"] as? String == clientID ||
                       (claims["aud"] as? [String])?.contains(clientID) == true

        guard claims["iss"] as? String == "https://auth.openai.com",
              audience,
              claims["nonce"] as? String == nonce,
              expiration > now - 60, notBefore <= now + 60, issuedAt <= now + 60,
              let subject = claims["sub"] as? String, !subject.isEmpty
        else { throw ChatGPTAuthError.invalidIDToken }
        return ChatGPTValidatedIdentity(subject: subject, email: claims["email"] as? String)
    }

    private static func decode(_ text: String) -> Data? {
        let s = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        return Data(base64Encoded: s + String(repeating: "=", count: (4 - s.count % 4) % 4))
    }

    private static func length(_ count: Int) -> [UInt8] {
        guard count >= 128 else { return [UInt8(count)] }
        var value = count
        var bytes = [UInt8]()
        while value > 0 {
            bytes.insert(UInt8(value & 0xff), at: 0)
            value >>= 8
        }
        return [0x80 | UInt8(bytes.count)] + bytes
    }

    private static func integer(_ raw: Data) -> [UInt8] {
        var bytes = Array(raw)
        if bytes.first.map({ $0 & 0x80 != 0 }) == true { bytes.insert(0, at: 0) }
        return [0x02] + length(bytes.count) + bytes
    }

    private static func sequence(_ value: [UInt8]) -> [UInt8] {
        [0x30] + length(value.count) + value
    }
}
