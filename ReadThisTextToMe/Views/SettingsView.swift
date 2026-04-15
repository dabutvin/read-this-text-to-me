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
                    VoicePickerView()
                        .environmentObject(appState)
                } header: {
                    Text("Voice")
                } footer: {
                    Text("Premium and Enhanced voices sound more natural. Download additional voices in Settings → Accessibility → Spoken Content → Voices.")
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
                    Text("Required for OpenAI OCR. Get a key at platform.openai.com")
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
