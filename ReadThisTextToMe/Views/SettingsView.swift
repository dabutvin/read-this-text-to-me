import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("openai_api_key") private var apiKey = ""
    @AppStorage("ocr_method") private var ocrMethod = "apple"
    @AppStorage("speech_rate") private var speechRate = 0.5

    var body: some View {
        NavigationStack {
            Form {
                Section("Speech") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Speech Rate")
                        HStack {
                            Image(systemName: "tortoise")
                                .foregroundStyle(.secondary)
                            Slider(value: $speechRate, in: 0.0...1.0)
                            Image(systemName: "hare")
                                .foregroundStyle(.secondary)
                        }
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
