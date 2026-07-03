import StandupKit
import UIKit

/// iOS implementation of `ExportService`.
///
/// `copySummary` puts the text on the system pasteboard; `saveCSV` writes the
/// CSV to a temporary file and presents a share sheet (`UIActivityViewController`)
/// from the active scene's key window, letting the user save it to Files, mail
/// it, AirDrop it, etc.
@MainActor
final class iOSExportService: ExportService {
    func copySummary(_ text: String) {
        UIPasteboard.general.string = text
    }

    func saveCSV(_ csv: String, suggestedName: String) {
        // Write the CSV to a temp file so the share sheet exposes a real,
        // correctly named document rather than a raw string.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(suggestedName)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return
        }

        guard let presenter = Self.topViewController() else { return }

        let activity = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        // Required on iPad: anchor the popover to the presenter's view.
        if let popover = activity.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        presenter.present(activity, animated: true)
    }

    /// Finds the top-most view controller of the foreground-active scene's key
    /// window, walking past any already-presented controllers.
    private static func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }

        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
