import AppKit
import StandupKit
import UniformTypeIdentifiers

/// macOS implementation of `ExportService` using the pasteboard and a save panel.
@MainActor
final class MacExportService: ExportService {
    func copySummary(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func saveCSV(_ csv: String, suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = suggestedName
        panel.begin { result in
            if result == .OK, let url = panel.url {
                try? csv.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
