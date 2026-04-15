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

    @Published var ttsEngine: TTSEngine {
        didSet { UserDefaults.standard.set(ttsEngine.rawValue, forKey: "tts_engine") }
    }

    @Published var openAIVoice: OpenAIVoice {
        didSet { UserDefaults.standard.set(openAIVoice.rawValue, forKey: "openai_voice") }
    }

    @Published var openAITTSModel: OpenAITTSModel {
        didSet { UserDefaults.standard.set(openAITTSModel.rawValue, forKey: "openai_tts_model") }
    }

    /// Tracks clipboard text that the user explicitly dismissed via the X button,
    /// so re-tapping "Paste" won't re-show the same content.
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

        let storedEngine = UserDefaults.standard.string(forKey: "tts_engine") ?? ""
        self.ttsEngine = TTSEngine(rawValue: storedEngine) ?? .system

        let storedOpenAIVoice = UserDefaults.standard.string(forKey: "openai_voice") ?? ""
        self.openAIVoice = OpenAIVoice(rawValue: storedOpenAIVoice) ?? .nova

        let storedTTSModel = UserDefaults.standard.string(forKey: "openai_tts_model") ?? ""
        self.openAITTSModel = OpenAITTSModel(rawValue: storedTTSModel) ?? .standard

        speechService.onFinished = { [weak self] in
            self?.speechState = .idle
        }
    }

    var speechRate: Float {
        speechSpeed.utteranceRate
    }

    var openAISpeedMultiplier: Double {
        Double(speechSpeed.rawValue) ?? 1.0
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
               provider.id == "clipboard",
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

    func processPastedContent(_ strings: [String]) async {
        let raw = strings.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !raw.isEmpty else {
            errorMessage = AppError.noTextFound.localizedDescription
            showError = true
            return
        }

        if let url = URL(string: raw),
           url.scheme == "http" || url.scheme == "https" {
            await extractTextFromURL(url)
        } else {
            applyPastedText(raw)
        }
    }

    private func applyPastedText(_ raw: String) {
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

    private func extractTextFromURL(_ url: URL) async {
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

        switch ttsEngine {
        case .system:
            speechService.speak(extractedText, rate: speechRate, voiceIdentifier: selectedVoiceIdentifier)
            speechState = .speaking

        case .openai:
            guard OpenAIClient().hasAPIKey else {
                errorMessage = "Add your OpenAI API key in Settings to use OpenAI voices."
                showError = true
                return
            }
            speechState = .speaking
            Task {
                do {
                    try await speechService.speakWithOpenAI(
                        extractedText,
                        voice: openAIVoice,
                        model: openAITTSModel,
                        speed: openAISpeedMultiplier
                    )
                } catch {
                    speechState = .idle
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
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
        if speechState == .speaking {
            speechService.changeRate(speechRate)
        }
    }
}

enum AppError: LocalizedError {
    case noTextFound
    case ocrFailed(String)
    case urlExtractionFailed(String)
    case providerUnavailable(String)
    case ttsFailed(String)

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
        case .ttsFailed(let detail):
            return "Text-to-speech failed: \(detail)"
        }
    }
}
