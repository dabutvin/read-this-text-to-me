import AVFoundation

enum SpeechSpeed: String, CaseIterable, Identifiable {
    case x0_5 = "0.5"
    case x0_75 = "0.75"
    case x1_0 = "1.0"
    case x1_25 = "1.25"
    case x1_5 = "1.5"
    case x1_75 = "1.75"
    case x2_0 = "2.0"

    var id: String { rawValue }

    var label: String {
        rawValue + "x"
    }

    /// AVSpeechUtterance rate values tuned for each multiplier.
    /// The default rate (0.5) maps to 1x; values above compress
    /// because AVSpeech's upper range gets unintelligible quickly.
    var utteranceRate: Float {
        switch self {
        case .x0_5:  return 0.35
        case .x0_75: return 0.42
        case .x1_0:  return AVSpeechUtteranceDefaultSpeechRate // 0.5
        case .x1_25: return 0.53
        case .x1_5:  return 0.56
        case .x1_75: return 0.59
        case .x2_0:  return 0.62
        }
    }

    var next: SpeechSpeed {
        let all = Self.allCases
        guard let idx = all.firstIndex(of: self) else { return self }
        let nextIdx = all.index(after: idx)
        return nextIdx < all.endIndex ? all[nextIdx] : all[all.startIndex]
    }

    static func from(stored: String) -> SpeechSpeed {
        SpeechSpeed(rawValue: stored) ?? .x1_0
    }
}
