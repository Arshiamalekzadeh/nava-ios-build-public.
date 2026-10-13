import SwiftUI
import UIKit

/// Explicit handoff to the official ChatGPT app/site; NOT an OAuth session or login.
enum ChatGPTBridge {
    static func openOfficialAppOrWebsite() {
        guard let destination = URL(string: "https://chatgpt.com") else { return }

        // Prefer the iOS app when the official Universal Link is installed.
        UIApplication.shared.open(destination, options: [.universalLinksOnly: true]) { accepted in
            if !accepted {
                UIApplication.shared.open(destination)
            }
        }
    }

    static func openVoiceShortcut(named rawName: String) -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }

        var url = URLComponents()
        url.scheme = "shortcuts"
        url.host = "run-shortcut"
        url.queryItems = [URLQueryItem(name: "name", value: name)]
        guard let destination = url.url else { return false }
        UIApplication.shared.open(destination)
        return true
    }
}
