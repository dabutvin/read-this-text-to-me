import AVFoundation

@MainActor
final class SpeechService: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?

    @Published var isSpeaking = false
    @Published var isPaused = false
    @Published var progress: Double = 0
    @Published var isLoadingAudio = false

    var onFinished: (() -> Void)?

    private var fullText: String = ""
    private var lastSpokenCharacterIndex: Int = 0
    private var currentVoiceIdentifier: String?
    private var activeEngine: TTSEngine = .system

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

    // MARK: - System TTS Playback

    func speak(_ text: String, rate: Float = AVSpeechUtteranceDefaultSpeechRate, voiceIdentifier: String? = nil) {
        stop()
        activeEngine = .system
        fullText = text
        lastSpokenCharacterIndex = 0
        currentVoiceIdentifier = voiceIdentifier
        startUtterance(from: 0, rate: rate, voiceIdentifier: voiceIdentifier)
    }

    func changeRate(_ rate: Float) {
        guard activeEngine == .system, isSpeaking, !fullText.isEmpty else { return }
        let resumeIndex = lastSpokenCharacterIndex
        synthesizer.stopSpeaking(at: .immediate)

        isSpeaking = true
        isPaused = false
        startUtterance(from: resumeIndex, rate: rate, voiceIdentifier: currentVoiceIdentifier)
    }

    func changeVoice(identifier: String, rate: Float) {
        guard activeEngine == .system, isSpeaking, !fullText.isEmpty else { return }
        let resumeIndex = lastSpokenCharacterIndex
        currentVoiceIdentifier = identifier
        synthesizer.stopSpeaking(at: .immediate)

        isSpeaking = true
        isPaused = false
        startUtterance(from: resumeIndex, rate: rate, voiceIdentifier: identifier)
    }

    // MARK: - OpenAI TTS Playback

    func speakWithOpenAI(
        _ text: String,
        voice: OpenAIVoice,
        model: OpenAITTSModel,
        speed: Double
    ) async throws {
        stop()
        activeEngine = .openai
        fullText = text
        isLoadingAudio = true

        let client = OpenAIClient()

        let chunks = chunkText(text, maxLength: 4096)
        var allAudioData = Data()

        for chunk in chunks {
            let audioData = try await client.synthesizeSpeech(
                text: chunk,
                voice: voice,
                model: model,
                speed: speed
            )
            allAudioData.append(audioData)
        }

        isLoadingAudio = false

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("openai_tts_\(UUID().uuidString).mp3")
        try allAudioData.write(to: tempURL)

        let player = try AVAudioPlayer(contentsOf: tempURL)
        player.delegate = self
        self.audioPlayer = player

        player.prepareToPlay()
        player.play()

        isSpeaking = true
        isPaused = false
        startProgressTimer()

        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Shared Controls

    func pause() {
        switch activeEngine {
        case .system:
            synthesizer.pauseSpeaking(at: .word)
        case .openai:
            audioPlayer?.pause()
        }
        isPaused = true
    }

    func resume() {
        switch activeEngine {
        case .system:
            synthesizer.continueSpeaking()
        case .openai:
            audioPlayer?.play()
            startProgressTimer()
        }
        isPaused = false
    }

    func stop() {
        stopProgressTimer()
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
        isPaused = false
        isLoadingAudio = false
        progress = 0
        fullText = ""
        lastSpokenCharacterIndex = 0
    }

    // MARK: - Private (System TTS)

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

        isSpeaking = true
        isPaused = false
        synthesizer.speak(utterance)
    }

    // MARK: - Private (OpenAI TTS)

    private func chunkText(_ text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else { return [text] }

        var chunks: [String] = []
        var remaining = text

        while !remaining.isEmpty {
            if remaining.count <= maxLength {
                chunks.append(remaining)
                break
            }

            let endIndex = remaining.index(remaining.startIndex, offsetBy: maxLength)
            let searchRange = remaining.startIndex..<endIndex

            var breakIndex = endIndex
            if let sentenceEnd = remaining.range(of: ".", options: .backwards, range: searchRange) {
                breakIndex = remaining.index(after: sentenceEnd.upperBound)
            } else if let spaceEnd = remaining.range(of: " ", options: .backwards, range: searchRange) {
                breakIndex = spaceEnd.upperBound
            }

            let chunk = String(remaining[remaining.startIndex..<breakIndex])
            chunks.append(chunk)
            remaining = String(remaining[breakIndex...])
        }

        return chunks
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.audioPlayer else { return }
                if player.duration > 0 {
                    self.progress = player.currentTime / player.duration
                }
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - Audio Session

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

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let utteranceOffset = characterRange.location + characterRange.length
        Task { @MainActor in
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
            if !self.isSpeaking {
                self.progress = 0
                self.onFinished?()
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension SpeechService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopProgressTimer()
            self.isSpeaking = false
            self.isPaused = false
            self.progress = 1.0
            self.audioPlayer = nil
            self.onFinished?()
        }
    }
}
