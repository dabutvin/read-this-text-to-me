import SwiftUI
import AVFoundation

@MainActor
final class AppState: ObservableObject {
    @Published var extractedText: String = ""
    @Published var speechState: SpeechState = .idle
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var showSettings: Bool = false
    @Published var showError: Bool = false

    /// Tracks clipboard text that the user explicitly dismissed via the X button,
    /// so re-tapping "Paste Text" won't re-show the same content.
    var lastDismissedClipboardText: String?

    let providerRegistry = ProviderRegistry()
    let speechService = SpeechService()
    let textProcessingService = TextProcessingService()
    lazy var ocrService = OCRService()

    init() {
        speechService.onFinished = { [weak self] in
            self?.speechState = .idle
        }
    }

    var speechRate: Float {
        let stored = UserDefaults.standard.double(forKey: "speech_rate")
        let normalized = stored > 0 ? stored : 0.5
        return Float(normalized) * AVSpeechUtteranceMaximumSpeechRate
    }

    func processInput(from provider: any TextInputProvider) async {
        isProcessing = true
        errorMessage = nil

        do {
            let rawText = try await provider.extractText()
            let cleaned = textProcessingService.clean(rawText)

            if cleaned.isEmpty {
                throw AppError.noTextFound
            }

            if let dismissed = lastDismissedClipboardText,
               provider.id == "clipboard_text",
               cleaned == dismissed {
                throw AppError.noTextFound
            }

            extractedText = cleaned
            lastDismissedClipboardText = nil
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isProcessing = false
    }

    func speak() {
        guard !extractedText.isEmpty else { return }
        speechService.speak(extractedText, rate: speechRate)
        speechState = .speaking
    }

    func pause() {
        speechService.pause()
        speechState = .paused
    }

    func resume() {
        speechService.resume()
        speechState = .speaking
    }

    func stop() {
        speechService.stop()
        speechState = .idle
    }

    func clearText() {
        stop()
        lastDismissedClipboardText = extractedText.isEmpty ? nil : extractedText
        extractedText = ""
    }
}

enum AppError: LocalizedError {
    case noTextFound
    case ocrFailed(String)
    case urlExtractionFailed(String)
    case providerUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "No text was found in the input."
        case .ocrFailed(let detail):
            return "OCR failed: \(detail)"
        case .urlExtractionFailed(let detail):
            return "Could not extract text from URL: \(detail)"
        case .providerUnavailable(let name):
            return "\(name) is not available on this device."
        }
    }
}
