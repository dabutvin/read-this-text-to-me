import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @AppStorage("openai_api_key") private var apiKey = ""
    @AppStorage("ocr_method") private var ocrMethod = "apple"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Speed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        SpeedSelectorView()
                            .environmentObject(appState)
                    }
                } header: {
                    Text("Speech")
                }

                Section {
                    Picker("Engine", selection: $appState.ttsEngine) {
                        ForEach(TTSEngine.allCases) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                } header: {
                    Text("Voice Engine")
                } footer: {
                    if appState.ttsEngine == .openai {
                        Text("OpenAI voices sound natural and expressive. Requires an API key and internet connection. Usage is billed to your OpenAI account.")
                    } else {
                        Text("System voices are free and work offline.")
                    }
                }

                if appState.ttsEngine == .system {
                    Section {
                        VoicePickerView()
                            .environmentObject(appState)
                    } header: {
                        Text("System Voice")
                    } footer: {
                        Text("Premium and Enhanced voices sound more natural. Download additional voices in Settings → Accessibility → Spoken Content → Voices.")
                    }
                }

                if appState.ttsEngine == .openai {
                    Section {
                        OpenAIVoicePickerView()
                            .environmentObject(appState)
                    } header: {
                        Text("OpenAI Voice")
                    }

                    Section {
                        Picker("Quality", selection: $appState.openAITTSModel) {
                            ForEach(OpenAITTSModel.allCases) { model in
                                Text(model.displayName).tag(model)
                            }
                        }
                    } header: {
                        Text("Audio Quality")
                    } footer: {
                        Text("HD produces richer audio but takes slightly longer to generate.")
                    }
                }

                Section("OCR") {
                    Picker("OCR Method", selection: $ocrMethod) {
                        Text("On-Device (Free)").tag("apple")
                        Text("OpenAI (Best Quality)").tag("openai")
                    }
                }

                Section {
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                } header: {
                    Text("OpenAI")
                } footer: {
                    Text("Required for OpenAI voices and OpenAI OCR. Get a key at platform.openai.com")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct VoicePickerView: View {
    @EnvironmentObject private var appState: AppState

    private var voices: [AVSpeechSynthesisVoice] {
        SpeechService.availableVoices()
    }

    var body: some View {
        if voices.isEmpty {
            Text("No voices available")
                .foregroundStyle(.secondary)
        } else {
            Picker("Voice", selection: voiceBinding) {
                Text("System Default").tag("")
                ForEach(voices, id: \.identifier) { voice in
                    Text(SpeechService.voiceDisplayName(voice))
                        .tag(voice.identifier)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    private var voiceBinding: Binding<String> {
        Binding(
            get: { appState.selectedVoiceIdentifier ?? "" },
            set: { newValue in
                appState.setVoice(newValue.isEmpty ? nil : newValue)
            }
        )
    }
}

struct OpenAIVoicePickerView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ForEach(OpenAIVoice.allCases) { voice in
            Button {
                appState.openAIVoice = voice
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(voice.displayName)
                            .foregroundStyle(.primary)
                        Text(voice.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if appState.openAIVoice == voice {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                            .fontWeight(.semibold)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
