import Foundation

struct OpenAIClient {
    private let baseURL = "https://api.openai.com/v1"

    var hasAPIKey: Bool {
        let key = UserDefaults.standard.string(forKey: "openai_api_key")
        return key != nil && !key!.isEmpty
    }

    private var apiKey: String? {
        UserDefaults.standard.string(forKey: "openai_api_key")
    }

    func recognizeText(base64Image: String) async throws -> String {
        guard let apiKey = apiKey else {
            throw AppError.ocrFailed("No OpenAI API key configured")
        }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Extract all text from this image. Return only the text content, preserving paragraph structure. Do not add any commentary or formatting."
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 4096
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw AppError.ocrFailed("OpenAI API returned status \(statusCode)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AppError.ocrFailed("Unexpected response format from OpenAI")
        }

        return content
    }
}
