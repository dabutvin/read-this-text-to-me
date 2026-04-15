import Foundation

struct TextProcessingService {
    func clean(_ text: String) -> String {
        var result = text

        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Collapse multiple newlines into double newline (paragraph break)
        result = result.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        // Collapse multiple spaces into single space
        result = result.replacingOccurrences(
            of: " {2,}",
            with: " ",
            options: .regularExpression
        )

        // Remove null bytes and other control characters (keep newlines and tabs)
        result = result.unicodeScalars.filter { scalar in
            scalar == "\n" || scalar == "\t" || !CharacterSet.controlCharacters.contains(scalar)
        }.map { String($0) }.joined()

        return result
    }
}
