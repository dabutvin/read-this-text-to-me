import SwiftUI
import UIKit
import PhotosUI

struct MainView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextPreviewView(text: appState.extractedText)
                    .frame(maxHeight: .infinity)

                if !appState.extractedText.isEmpty {
                    PlaybackControlsView()
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                InputSourceGrid(
                    selectedPhoto: $selectedPhoto,
                    showCamera: $showCamera
                )
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("Read This Text To Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $appState.showSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    Task { await processImage(image) }
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let item = newValue else { return }
                Task { await loadPhoto(item) }
            }
            .alert("Error", isPresented: $appState.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(appState.errorMessage ?? "Something went wrong")
            }
            .overlay {
                if appState.isProcessing {
                    ProcessingOverlay()
                }
            }
        }
    }

    @MainActor
    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            appState.errorMessage = "Could not load photo"
            appState.showError = true
            return
        }
        await processImage(image)
    }

    @MainActor
    private func processImage(_ image: UIImage) async {
        appState.isProcessing = true
        do {
            let text = try await appState.ocrService.recognizeText(in: image)
            appState.extractedText = appState.textProcessingService.clean(text)
            if appState.extractedText.isEmpty {
                throw AppError.noTextFound
            }
        } catch {
            appState.errorMessage = error.localizedDescription
            appState.showError = true
        }
        appState.isProcessing = false
    }
}

struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Extracting text...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage) -> Void

        init(onImageCaptured: @escaping (UIImage) -> Void) {
            self.onImageCaptured = onImageCaptured
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
