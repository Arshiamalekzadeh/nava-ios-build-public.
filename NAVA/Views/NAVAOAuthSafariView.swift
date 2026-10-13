import SwiftUI
import SafariServices

/// Safari chrome is intentional: credentials are entered only on OpenAI's
/// domain, never in a NAVA-owned WKWebView or a custom credential form.
struct NAVAOAuthSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let browser = SFSafariViewController(url: url)
        browser.preferredControlTintColor = UIColor(red: 232 / 255, green: 80 / 255, blue: 2 / 255, alpha: 1)
        browser.dismissButtonStyle = .close
        return browser
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
