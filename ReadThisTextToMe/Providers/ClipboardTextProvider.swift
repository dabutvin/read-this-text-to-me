import UIKit

struct ClipboardTextProvider: TextInputProvider {
    let id = "clipboard"
    let displayName = "Paste"
    let icon = "doc.on.clipboard"
    let priority = 10

    @MainActor
    func extractText() async throws -> String {
        guard UIPasteboard.general.hasStrings,
              let text = UIPasteboard.general.string,
              !text.isEmpty else {
            throw AppError.noTextFound
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed),
           url.scheme == "http" || url.scheme == "https" {
            return try await URLExtractionService().extractText(from: url)
        }

        return text
    }
}
