import UIKit
import Vision

@MainActor
final class OCRService: ObservableObject {

    enum OCRMethod: String {
        case appleVision = "apple"
        case openAI = "openai"
    }

    var preferredMethod: OCRMethod {
        let stored = UserDefaults.standard.string(forKey: "ocr_method") ?? "apple"
        return OCRMethod(rawValue: stored) ?? .appleVision
    }

    func recognizeText(in image: UIImage) async throws -> String {
        switch preferredMethod {
        case .appleVision:
            return try await recognizeWithVision(image)
        case .openAI:
            return try await recognizeWithOpenAI(image)
        }
    }

    // MARK: - Apple Vision (free, on-device)

    private func recognizeWithVision(_ image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw AppError.ocrFailed("Could not process image")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: AppError.ocrFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: AppError.ocrFailed("No text observations"))
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: AppError.ocrFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - OpenAI Vision (requires API key)

    private func recognizeWithOpenAI(_ image: UIImage) async throws -> String {
        let client = OpenAIClient()

        guard client.hasAPIKey else {
            throw AppError.ocrFailed("OpenAI API key not configured. Go to Settings to add it.")
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AppError.ocrFailed("Could not encode image")
        }

        let base64Image = imageData.base64EncodedString()
        return try await client.recognizeText(base64Image: base64Image)
    }
}
