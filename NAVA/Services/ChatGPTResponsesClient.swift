import Foundation

enum ChatGPTResponsesClient {
    static func reply(history: [NAVAMessage], accessToken: String) async throws -> String {
        let historyItems: [[String: String]] = history.suffix(16).map { message in
            ["role": message.role == .user ? "user" : "assistant", "content": message.text]
        }
        let payload: [String: Any] = [
            "model": "gpt-6.1-sol",
            "instructions": "You are NAVA, a concise, capable Persian-first personal assistant on iOS. Answer in the user's language. Do not claim access to the official ChatGPT conversation history, iPhone system permissions, or tools not actually available.",
            "input": historyItems,
            "store": false,
            "stream": true
        ]
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else {
            throw ChatGPTAuthError.invalidResponse
        }
        guard (200..<300).contains(status) else { throw ChatGPTAuthError.failedRequest(status) }
        var output = ""
        var completed = false
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonLine = String(line.dropFirst(6))
            if jsonLine == "[DONE]" { break }
            guard let eventBytes = jsonLine.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: eventBytes) as? [String: Any],
                  let eventType = event["type"] as? String else { continue }
            switch eventType {
            case "response.output_text.delta":
                if let delta = event["delta"] as? String { output += delta }
            case "response.completed":
                completed = true
                if output.isEmpty,
                   let body = event["response"] as? [String: Any],
                   let items = body["output"] as? [[String: Any]] {
                    output = items.flatMap { ($0["content"] as? [[String: Any]]) ?? [] }
                        .compactMap { $0["text"] as? String }.joined()
                }
            case "response.failed":
                throw ChatGPTAuthError.invalidResponse
            default: break
            }
            if completed { break }
        }
        guard completed, !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ChatGPTAuthError.invalidResponse
        }
        return output
    }
}
