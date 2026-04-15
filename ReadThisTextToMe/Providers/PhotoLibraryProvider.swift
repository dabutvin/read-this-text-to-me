import SwiftUI
import PhotosUI

struct PhotoLibraryProvider: TextInputProvider {
    let id = "photo_library"
    let displayName = "Photo Library"
    let icon = "photo.on.rectangle"
    let priority = 30

    @MainActor
    func extractText() async throws -> String {
        // Photo picking is handled by the UI layer via PhotosPicker.
        // This provider is a marker; actual image → text flows through
        // the AppState.processImage() path.
        throw AppError.providerUnavailable("Use the photo picker in the UI")
    }
}
