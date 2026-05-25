import Foundation

enum AIChunkTextNormalizer {
    static func normalizedSentence(_ sentence: String) -> String {
        var normalized = ""
        var previousWasSpace = false

        for scalar in sentence.unicodeScalars {
            if shouldReplaceWithSpace(scalar) {
                if !previousWasSpace {
                    normalized.append(" ")
                    previousWasSpace = true
                }
            } else {
                normalized.unicodeScalars.append(scalar)
                previousWasSpace = false
            }
        }

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func shouldReplaceWithSpace(_ scalar: UnicodeScalar) -> Bool {
        CharacterSet.whitespacesAndNewlines.contains(scalar)
            || CharacterSet.punctuationCharacters.contains(scalar)
    }
}
