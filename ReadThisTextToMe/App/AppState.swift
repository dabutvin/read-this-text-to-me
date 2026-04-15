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

    @Published var speechSpeed: SpeechSpeed {
        didSet { UserDefaults.standard.set(speechSpeed.rawValue, forKey: "speech_speed") }
    }

    @Published var selectedVoiceIdentifier: String? {
        didSet { UserDefaults.standard.set(selectedVoiceIdentifier ?? "", forKey: "selected_voice") }
    }

    /// Tracks clipboard text that the user explicitly dismissed via the X button,
    /// so re-tapping "Paste Text" won't re-show the same content.
    var lastDismissedClipboardText: String?

    let providerRegistry = ProviderRegistry()
    let speechService = SpeechService()
    let textProcessingService = TextProcessingService()
    lazy var ocrService = OCRService()

    init() {
        let storedSpeed = UserDefaults.standard.string(forKey: "speech_speed") ?? ""
        self.speechSpeed = SpeechSpeed.from(stored: storedSpeed)

        let storedVoice = UserDefaults.standard.string(forKey: "selected_voice") ?? ""
        self.selectedVoiceIdentifier = storedVoice.isEmpty ? nil : storedVoice

        speechService.onFinished = { [weak self] in
            self?.speechState = .idle
        }
    }

    var speechRate: Float {
        speechSpeed.utteranceRate
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

    func processPastedText(_ strings: [String]) {
        let raw = strings.joined(separator: "\n")
        let cleaned = textProcessingService.clean(raw)

        guard !cleaned.isEmpty else {
            errorMessage = AppError.noTextFound.localizedDescription
            showError = true
            return
        }

        if let dismissed = lastDismissedClipboardText, cleaned == dismissed {
            errorMessage = AppError.noTextFound.localizedDescription
            showError = true
            return
        }

        extractedText = cleaned
        lastDismissedClipboardText = nil
    }

    func processPastedURL(_ strings: [String]) async {
        guard let urlString = strings.first,
              let url = URL(string: urlString),
              url.scheme == "http" || url.scheme == "https" else {
            errorMessage = AppError.urlExtractionFailed("No valid URL found").localizedDescription
            showError = true
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            let service = URLExtractionService()
            let rawText = try await service.extractText(from: url)
            let cleaned = textProcessingService.clean(rawText)

            if cleaned.isEmpty {
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
        speechService.speak(extractedText, rate: speechRate, voiceIdentifier: selectedVoiceIdentifier)
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

    func cycleSpeed() {
        speechSpeed = speechSpeed.next
        applySpeedChange()
    }

    func setSpeed(_ speed: SpeechSpeed) {
        speechSpeed = speed
        applySpeedChange()
    }

    func setVoice(_ identifier: String?) {
        selectedVoiceIdentifier = identifier
        if speechState == .speaking {
            speechService.changeVoice(identifier: identifier ?? "", rate: speechRate)
        }
    }

    func clearText() {
        stop()
        lastDismissedClipboardText = extractedText.isEmpty ? nil : extractedText
        extractedText = ""
    }

    private func applySpeedChange() {
        switch speechState {
        case .speaking:
            speechService.changeRate(speechRate)
        case .paused:
            speechService.changeRate(speechRate)
            speechState = .speaking
        case .idle:
            break
        }
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
