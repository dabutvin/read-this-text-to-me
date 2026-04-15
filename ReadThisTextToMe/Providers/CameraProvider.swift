import SwiftUI

struct CameraProvider: TextInputProvider {
    let id = "camera"
    let displayName = "Camera"
    let icon = "camera"
    let priority = 40

    @MainActor
    func extractText() async throws -> String {
        // Camera capture is handled by the UI layer via UIImagePickerController.
        // This provider is a marker; actual image → text flows through
        // the AppState.processImage() path.
        throw AppError.providerUnavailable("Use the camera picker in the UI")
    }
}
