import Foundation

/// Central registry of all available input providers.
/// Add new providers here — they show up in the UI automatically.
@MainActor
final class ProviderRegistry: ObservableObject {
    @Published private(set) var providers: [any TextInputProvider] = []

    init() {
        registerDefaults()
    }

    private func registerDefaults() {
        providers = [
            ClipboardTextProvider(),
            PhotoLibraryProvider(),
            CameraProvider(),
        ].sorted { $0.priority < $1.priority }
    }

    func register(_ provider: any TextInputProvider) {
        providers.append(provider)
        providers.sort { $0.priority < $1.priority }
    }
}
