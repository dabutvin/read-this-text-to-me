import Foundation
import SwiftSoup

struct URLExtractionService {

    func extractText(from url: URL) async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw AppError.urlExtractionFailed("HTTP \(statusCode)")
        }

        guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .ascii) else {
            throw AppError.urlExtractionFailed("Could not decode response")
        }

        return try extractReadableText(from: html)
    }

    private func extractReadableText(from html: String) throws -> String {
        let doc = try SwiftSoup.parse(html)

        // Remove non-content elements
        let removeTags = ["script", "style", "nav", "footer", "header", "aside", "iframe", "noscript"]
        for tag in removeTags {
            try doc.select(tag).remove()
        }

        // Try to find the main content area
        let contentSelectors = [
            "article",
            "[role=main]",
            "main",
            ".post-content",
            ".article-content",
            ".entry-content",
            ".content",
            "#content",
        ]

        for selector in contentSelectors {
            let elements = try doc.select(selector)
            if let element = elements.first() {
                let text = try element.text()
                if text.count > 100 {
                    return text
                }
            }
        }

        // Fallback: get body text
        if let body = doc.body() {
            return try body.text()
        }

        throw AppError.urlExtractionFailed("No readable text found")
    }
}
