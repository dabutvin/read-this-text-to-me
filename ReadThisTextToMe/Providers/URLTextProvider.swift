import UIKit

struct URLTextProvider: TextInputProvider {
    let id = "url_text"
    let displayName = "Paste URL"
    let icon = "link"
    let priority = 20

    @MainActor
    func extractText() async throws -> String {
        guard let clipboardString = UIPasteboard.general.string,
              let url = URL(string: clipboardString),
              url.scheme == "http" || url.scheme == "https" else {
            throw AppError.urlExtractionFailed("No valid URL found on clipboard")
        }

        let service = URLExtractionService()
        return try await service.extractText(from: url)
    }
}
