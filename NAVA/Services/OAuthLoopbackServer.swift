import Foundation
import Network

/// The OSS ChatGPT flow requires the exact http://127.0.0.1:<port>/auth/callback URI.
/// Keeping Safari in an in-app SFSafariViewController allows the listener to run
/// while the authorization UI is visible on iOS.
final class OAuthLoopbackServer {
    private let queue = DispatchQueue(label: "com.nava.oauth.loopback")
    private var listener: NWListener?
    private let onRedirect: (URL) -> Void

    init(onRedirect: @escaping (URL) -> Void) {
        self.onRedirect = onRedirect
    }

    func start() async throws -> UInt16 {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        self.listener = listener

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            listener.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    if let port = listener.port?.rawValue, port != 0 {
                        continuation.resume(returning: port)
                    } else {
                        continuation.resume(throwing: OAuthLoopbackError.portUnavailable)
                    }
                case .failed(let error):
                    resumed = true
                    continuation.resume(throwing: error)
                case .cancelled:
                    resumed = true
                    continuation.resume(throwing: OAuthLoopbackError.cancelled)
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.start(queue: queue)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }
            guard let data,
                  let request = String(data: data, encoding: .utf8),
                  let firstLine = request.components(separatedBy: "\r\n").first,
                  firstLine.hasPrefix("GET "),
                  let path = firstLine.split(separator: " ").dropFirst().first,
                  path.hasPrefix("/auth/callback?"),
                  let port = self.listener?.port?.rawValue,
                  let url = URL(string: "http://127.0.0.1:\(port)\(path)")
            else {
                self.reply(to: connection, status: "404 Not Found", html: "Not found")
                return
            }

            // OAuth validation is performed by the manager before exchanging any code.
            self.reply(to: connection, status: "200 OK",
                       html: "<html><meta charset='utf-8'><body style='font:18px -apple-system;text-align:center;padding:40px;background:#111;color:white'>NAVA — به برنامه برگردید.</body></html>")
            self.onRedirect(url)
        }
    }

    private func reply(to connection: NWConnection, status: String, html: String) {
        let body = Data(html.utf8)
        let header = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(header.utf8) + body, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

enum OAuthLoopbackError: LocalizedError {
    case portUnavailable, cancelled

    var errorDescription: String? {
        switch self {
        case .portUnavailable: "پورت محلی ورود به ChatGPT در دسترس نیست."
        case .cancelled: "فرایند ورود متوقف شد."
        }
    }
}
