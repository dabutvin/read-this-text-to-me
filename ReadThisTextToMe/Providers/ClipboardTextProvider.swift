import UIKit

struct ClipboardTextProvider: TextInputProvider {
    let id = "clipboard_text"
    let displayName = "Paste Text"
    let icon = "doc.on.clipboard"
    let priority = 10

    @MainActor
    func extractText() async throws -> String {
        guard UIPasteboard.general.hasStrings,
              let text = UIPasteboard.general.string,
              !text.isEmpty else {
            throw AppError.noTextFound
        }
        return text
    }
}
