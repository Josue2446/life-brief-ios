import SwiftUI
import SafariServices

/// In-app Safari sheet that keeps reading seamless within LifeBrief
/// while providing Apple Safari's native Reader mode, SSL security indicators, and Done button.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        let safariVC = SFSafariViewController(url: url, configuration: config)
        safariVC.preferredControlTintColor = .tintColor
        safariVC.dismissButtonStyle = .done
        return safariVC
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
