import AVFoundation

@MainActor
final class SpeechService: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    @Published var isSpeaking = false
    @Published var isPaused = false
    @Published var progress: Double = 0

    var onFinished: (() -> Void)?

    private var fullText: String = ""
    private var lastSpokenCharacterIndex: Int = 0
    private var currentVoiceIdentifier: String?
    private var currentUtterance: AVSpeechUtterance?

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    // MARK: - Voice helpers

    static func availableVoices(for language: String = "en") -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(language) }
            .sorted { lhs, rhs in
                if lhs.quality != rhs.quality {
                    return lhs.quality.rawValue > rhs.quality.rawValue
                }
                return lhs.name < rhs.name
            }
    }

    static func voiceDisplayName(_ voice: AVSpeechSynthesisVoice) -> String {
        let quality: String
        switch voice.quality {
        case .premium:  quality = "Premium"
        case .enhanced: quality = "Enhanced"
        default:        quality = "Default"
        }
        let region = Locale.current.localizedString(forLanguageCode: voice.language) ?? voice.language
        return "\(voice.name) (\(quality) · \(region))"
    }

    // MARK: - Playback

    func speak(_ text: String, rate: Float = AVSpeechUtteranceDefaultSpeechRate, voiceIdentifier: String? = nil) {
        stop()
        fullText = text
        lastSpokenCharacterIndex = 0
        currentVoiceIdentifier = voiceIdentifier
        startUtterance(from: 0, rate: rate, voiceIdentifier: voiceIdentifier)
    }

    func changeRate(_ rate: Float) {
        guard (isSpeaking || isPaused), !fullText.isEmpty else { return }
        let resumeIndex = lastSpokenCharacterIndex
        synthesizer.stopSpeaking(at: .immediate)

        startUtterance(from: resumeIndex, rate: rate, voiceIdentifier: currentVoiceIdentifier)
    }

    func changeVoice(identifier: String, rate: Float) {
        guard isSpeaking, !fullText.isEmpty else { return }
        let resumeIndex = lastSpokenCharacterIndex
        currentVoiceIdentifier = identifier
        synthesizer.stopSpeaking(at: .immediate)

        isSpeaking = true
        isPaused = false
        startUtterance(from: resumeIndex, rate: rate, voiceIdentifier: identifier)
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
    }

    func resume() {
        synthesizer.continueSpeaking()
        isPaused = false
    }

    func stop() {
        currentUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
        progress = 0
        fullText = ""
        lastSpokenCharacterIndex = 0
    }

    // MARK: - Private

    private func startUtterance(from characterIndex: Int, rate: Float, voiceIdentifier: String?) {
        guard characterIndex < fullText.count else {
            isSpeaking = false
            onFinished?()
            return
        }

        let startIndex = fullText.index(fullText.startIndex, offsetBy: characterIndex)
        let remainingText = String(fullText[startIndex...])

        let utterance = AVSpeechUtterance(string: remainingText)

        if let id = voiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: id) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        currentUtterance = utterance
        isSpeaking = true
        isPaused = false
        synthesizer.speak(utterance)
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc nonisolated private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .ended {
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                Task { @MainActor in
                    if self.isPaused {
                        self.resume()
                    }
                }
            }
        }
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let utteranceOffset = characterRange.location + characterRange.length
        Task { @MainActor in
            guard utterance === self.currentUtterance else { return }
            let textLength = self.fullText.count
            guard textLength > 0 else { return }

            let offsetFromFullText = textLength - utterance.speechString.count
            let absolutePosition = offsetFromFullText + utteranceOffset
            self.lastSpokenCharacterIndex = min(absolutePosition, textLength)
            self.progress = min(Double(absolutePosition) / Double(textLength), 1.0)
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            guard utterance === self.currentUtterance else { return }
            self.currentUtterance = nil
            self.isSpeaking = false
            self.isPaused = false
            self.progress = 1.0
            self.onFinished?()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            guard utterance === self.currentUtterance else { return }
            self.currentUtterance = nil
            self.isSpeaking = false
            self.isPaused = false
            self.progress = 0
            self.onFinished?()
        }
    }
}
