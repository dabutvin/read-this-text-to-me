import SwiftUI

struct TextPreviewView: View {
    let text: String

    var body: some View {
        Group {
            if text.isEmpty {
                emptyState
            } else {
                textContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Choose an input below")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Paste text, a URL, or pick a photo\nand it will be read aloud")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var textContent: some View {
        ScrollView {
            Text(text)
                .font(.body)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .scrollIndicators(.visible)
    }
}
