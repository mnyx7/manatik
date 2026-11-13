import MessageUI
import UIKit

/// Sends feedback to the developer by email: from a shake anywhere in the
/// app, or from Settings.
///
/// The app has no server, so email is the channel. Mail opens prefilled with
/// the app version, iOS version and device, and (for a shake) a screenshot of
/// the screen the user was on. The user sees all of it and can remove the
/// screenshot before sending, since it may show amounts.
@MainActor
final class FeedbackMailer: NSObject, MFMailComposeViewControllerDelegate {
    static let shared = FeedbackMailer()
    static let address = "minaya.yagubova@icloud.com"

    private var isPresenting = false

    /// Called on shake: captures the current screen first, before Mail covers it.
    /// While the user is typing, shake belongs to iOS's "Undo Typing", so it
    /// is left alone.
    func reportFromShake() {
        guard !isPresenting, !Self.isEditingText, let window = Self.keyWindow else { return }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let screenshot = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        compose(screenshot: screenshot)
    }

    func compose(screenshot: UIImage? = nil) {
        guard !isPresenting, let presenter = Self.topViewController else { return }

        let subject = NSLocalizedString("muna feedback", comment: "Feedback email subject")

        guard MFMailComposeViewController.canSendMail() else {
            // No account in Apple Mail: hand over to whatever mail app is set
            // as default. A mailto link cannot carry the screenshot.
            openMailtoLink(subject: subject, presenter: presenter)
            return
        }

        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = self
        mail.setToRecipients([Self.address])
        mail.setSubject(subject)
        mail.setMessageBody(Self.bodyTemplate, isHTML: false)
        if let data = screenshot?.jpegData(compressionQuality: 0.8) {
            mail.addAttachmentData(data, mimeType: "image/jpeg", fileName: "screenshot.jpg")
        }
        isPresenting = true
        presenter.present(mail, animated: true)
    }

    nonisolated func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        Task { @MainActor in
            controller.dismiss(animated: true)
            self.isPresenting = false
        }
    }

    // MARK: - Fallback

    private func openMailtoLink(subject: String, presenter: UIViewController) {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: Self.bodyTemplate),
        ]
        guard let url = components.url else { return }

        UIApplication.shared.open(url) { opened in
            guard !opened else { return }
            let alert = UIAlertController(
                title: NSLocalizedString("No mail app found", comment: "Feedback fallback"),
                message: String(
                    format: NSLocalizedString("Write to %@ from any mail app.", comment: "Feedback fallback"),
                    Self.address
                ),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("Copy address", comment: "Feedback fallback"), style: .default) { _ in
                UIPasteboard.general.string = Self.address
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert"), style: .cancel))
            presenter.present(alert, animated: true)
        }
    }

    // MARK: - Helpers

    private static var isEditingText: Bool {
        FirstResponderProbe.current is UITextInput
    }

    /// Blank lines for the user's message, then the context that makes a
    /// report useful.
    private static var bodyTemplate: String {
        "\n\n\n---\nmuna \(AppVersionProvider.versionText)\niOS \(UIDevice.current.systemVersion) · \(deviceModel)"
    }

    private static var deviceModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    private static var topViewController: UIViewController? {
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

/// UIKit has no public "current first responder"; sending an action to nil
/// delivers it to the first responder, which records itself.
@MainActor
private enum FirstResponderProbe {
    private static weak var found: UIResponder?

    static var current: UIResponder? {
        found = nil
        UIApplication.shared.sendAction(#selector(UIResponder.munaRecordFirstResponder), to: nil, from: nil, for: nil)
        return found
    }

    static func record(_ responder: UIResponder) { found = responder }
}

extension UIResponder {
    @objc fileprivate func munaRecordFirstResponder() {
        FirstResponderProbe.record(self)
    }
}

/// SwiftUI has no shake event. The window is the last responder in the
/// chain, so every shake that nothing else handled reaches it here.
extension UIWindow {
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            FeedbackMailer.shared.reportFromShake()
        }
        super.motionEnded(motion, with: event)
    }
}
