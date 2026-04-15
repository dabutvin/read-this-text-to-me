import Foundation

enum TTSEngine: String, CaseIterable, Identifiable {
    case system = "system"
    case openai = "openai"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System (Free)"
        case .openai: return "OpenAI (Natural)"
        }
    }
}

enum OpenAIVoice: String, CaseIterable, Identifiable {
    case alloy
    case ash
    case ballad
    case coral
    case echo
    case fable
    case nova
    case onyx
    case sage
    case shimmer

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var subtitle: String {
        switch self {
        case .alloy:   return "Neutral & balanced"
        case .ash:     return "Warm & conversational"
        case .ballad:  return "Soft & gentle"
        case .coral:   return "Clear & professional"
        case .echo:    return "Deep & authoritative"
        case .fable:   return "Expressive & British"
        case .nova:    return "Warm & friendly"
        case .onyx:    return "Deep & rich"
        case .sage:    return "Calm & measured"
        case .shimmer: return "Bright & optimistic"
        }
    }
}

enum OpenAITTSModel: String, CaseIterable, Identifiable {
    case standard = "tts-1"
    case hd = "tts-1-hd"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard (Faster)"
        case .hd:       return "HD (Higher Quality)"
        }
    }
}
