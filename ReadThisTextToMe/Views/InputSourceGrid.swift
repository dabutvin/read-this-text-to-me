import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct InputSourceGrid: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var showCamera: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            pasteTextButton
            pasteURLButton

            ForEach(appState.providerRegistry.providers, id: \.id) { provider in
                switch provider.id {
                case "clipboard_text", "url_text":
                    EmptyView()
                default:
                    inputButton(for: provider)
                }
            }
        }
    }

    private var pasteTextButton: some View {
        PasteButton(payloadType: String.self) { strings in
            appState.processPastedText(strings)
        }
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .labelStyle(PasteInputLabelStyle(icon: "doc.on.clipboard", label: "Paste Text"))
        .tint(.clear)
    }

    private var pasteURLButton: some View {
        PasteButton(payloadType: String.self) { strings in
            Task { await appState.processPastedURL(strings) }
        }
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .labelStyle(PasteInputLabelStyle(icon: "link", label: "Paste URL"))
        .tint(.clear)
    }

    @ViewBuilder
    private func inputButton(for provider: any TextInputProvider) -> some View {
        switch provider.id {
        case "photo_library":
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                InputSourceButton(icon: provider.icon, label: provider.displayName)
            }
        case "camera":
            Button { showCamera = true } label: {
                InputSourceButton(icon: provider.icon, label: provider.displayName)
            }
        default:
            Button {
                Task { await appState.processInput(from: provider) }
            } label: {
                InputSourceButton(icon: provider.icon, label: provider.displayName)
            }
        }
    }
}

private struct PasteInputLabelStyle: LabelStyle {
    let icon: String
    let label: String

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
        .foregroundStyle(.primary)
    }
}

struct InputSourceButton: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
        .foregroundStyle(.primary)
    }
}
