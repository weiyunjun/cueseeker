import Foundation
import NaturalLanguage

public enum SubtitleLanguageCode: String, CaseIterable, Codable, Hashable, Sendable {
    case english = "en"
    case japanese = "ja"
    case chinese = "zh"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case unknown = "unknown"

    public var isChinese: Bool {
        self == .chinese || self == .simplifiedChinese || self == .traditionalChinese
    }
}

public enum SubtitleLanguageConfidenceBand: String, Codable, Equatable, Sendable {
    case veryHigh = ">=0.95"
    case high = "0.90-0.95"
    case medium = "0.80-0.90"
    case low = "0.60-0.80"
    case veryLow = "<0.60"
    case none

    public static func band(for confidence: Double) -> SubtitleLanguageConfidenceBand {
        if confidence >= 0.95 { return .veryHigh }
        if confidence >= 0.90 { return .high }
        if confidence >= 0.80 { return .medium }
        if confidence >= 0.60 { return .low }
        if confidence > 0 { return .veryLow }
        return .none
    }
}

public struct SubtitleLanguageDistribution: Codable, Equatable, Sendable {
    public let language: SubtitleLanguageCode
    public let share: Double

    public init(language: SubtitleLanguageCode, share: Double) {
        self.language = language
        self.share = share
    }
}

public struct SubtitleLanguageDetectionResult: Codable, Equatable, Sendable {
    public let languages: Set<SubtitleLanguageCode>
    public let confidence: Double
    public let confidenceBand: SubtitleLanguageConfidenceBand
    public let segmentCount: Int
    public let effectiveCharacterCount: Int
    public let distribution: [SubtitleLanguageDistribution]

    public var isUnknown: Bool {
        languages == [.unknown]
    }

    public init(
        languages: Set<SubtitleLanguageCode>,
        confidence: Double,
        segmentCount: Int,
        effectiveCharacterCount: Int,
        distribution: [SubtitleLanguageDistribution]
    ) {
        let resolvedLanguages = languages.isEmpty ? Set([SubtitleLanguageCode.unknown]) : languages
        self.languages = resolvedLanguages
        self.confidence = max(0, min(1, confidence))
        self.confidenceBand = SubtitleLanguageConfidenceBand.band(for: self.confidence)
        self.segmentCount = segmentCount
        self.effectiveCharacterCount = effectiveCharacterCount
        self.distribution = distribution
    }

    public static func unknown(
        segmentCount: Int = 0,
        effectiveCharacterCount: Int = 0
    ) -> SubtitleLanguageDetectionResult {
        SubtitleLanguageDetectionResult(
            languages: [.unknown],
            confidence: 0,
            segmentCount: segmentCount,
            effectiveCharacterCount: effectiveCharacterCount,
            distribution: []
        )
    }
}

public struct SubtitleLanguageRecognizer: Sendable {
    public static let algorithmVersion = 2
    public static let defaultConfidenceThreshold = 0.9

    public let confidenceThreshold: Double
    public let minimumEffectiveCharacterCount: Int
    public let minimumSegmentEffectiveCharacterCount: Int
    public let minimumLanguageShare: Double

    public init(
        confidenceThreshold: Double = SubtitleLanguageRecognizer.defaultConfidenceThreshold,
        minimumEffectiveCharacterCount: Int = 12,
        minimumSegmentEffectiveCharacterCount: Int = 4,
        minimumLanguageShare: Double = 0.18
    ) {
        self.confidenceThreshold = max(0, min(1, confidenceThreshold))
        self.minimumEffectiveCharacterCount = max(0, minimumEffectiveCharacterCount)
        self.minimumSegmentEffectiveCharacterCount = max(1, minimumSegmentEffectiveCharacterCount)
        self.minimumLanguageShare = max(0, min(1, minimumLanguageShare))
    }

    public func detectLanguages(in segments: [String]) -> SubtitleLanguageDetectionResult {
        let candidates = segments.compactMap(candidateSegment(from:))
        let effectiveCharacterCount = candidates.reduce(0) { $0 + $1.stats.effectiveCharacters }
        guard !candidates.isEmpty,
              effectiveCharacterCount >= minimumEffectiveCharacterCount
        else {
            return .unknown(
                segmentCount: candidates.count,
                effectiveCharacterCount: effectiveCharacterCount
            )
        }

        let combinedText = candidates.map(\.text).joined(separator: "\n")
        let combinedStats = ScriptStats(text: combinedText)
        let languageShares = recognizedLanguageShares(for: combinedText, stats: combinedStats)
        let scriptShares = scriptLanguageShares(for: candidates)
        guard !languageShares.isEmpty else {
            return .unknown(
                segmentCount: candidates.count,
                effectiveCharacterCount: effectiveCharacterCount
            )
        }

        let distribution = languageShares
            .map { language, share in
                SubtitleLanguageDistribution(language: language, share: share)
            }
            .sorted { lhs, rhs in
                if lhs.share == rhs.share {
                    return lhs.language.rawValue < rhs.language.rawValue
                }
                return lhs.share > rhs.share
            }

        let selected = selectedLanguages(from: languageShares, scriptShares: scriptShares)
        let confidence = confidence(for: selected, shares: languageShares, scriptShares: scriptShares)
        guard confidence >= confidenceThreshold else {
            return SubtitleLanguageDetectionResult(
                languages: [.unknown],
                confidence: confidence,
                segmentCount: candidates.count,
                effectiveCharacterCount: effectiveCharacterCount,
                distribution: distribution
            )
        }

        return SubtitleLanguageDetectionResult(
            languages: selected,
            confidence: confidence,
            segmentCount: candidates.count,
            effectiveCharacterCount: effectiveCharacterCount,
            distribution: distribution
        )
    }

    public static func languageCode(forNaturalLanguageIdentifier identifier: String) -> SubtitleLanguageCode? {
        switch identifier.lowercased() {
        case "en":
            return .english
        case "ja":
            return .japanese
        case "zh":
            return .chinese
        case "zh-hans", "zh-cn", "zh-sg":
            return .simplifiedChinese
        case "zh-hant", "zh-tw", "zh-hk", "zh-mo":
            return .traditionalChinese
        default:
            return nil
        }
    }

    private func candidateSegment(from text: String) -> LanguageCandidate? {
        let normalized = text
            .replacingOccurrences(of: "\u{feff}", with: "")
            .replacingOccurrences(of: "\\N", with: " ")
            .replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\\h", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let stats = ScriptStats(text: normalized)

        guard stats.effectiveCharacters >= minimumSegmentEffectiveCharacterCount,
              stats.languageLikeCharacters >= 3
        else {
            return nil
        }

        return LanguageCandidate(text: normalized, stats: stats)
    }

    private func recognizedLanguageShares(
        for text: String,
        stats: ScriptStats
    ) -> [SubtitleLanguageCode: Double] {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 5)
            .map { (language: $0.key.rawValue, confidence: $0.value) }
            .sorted { $0.confidence > $1.confidence }

        var shares: [SubtitleLanguageCode: Double] = [:]
        for hypothesis in hypotheses {
            guard let language = Self.languageCode(forNaturalLanguageIdentifier: hypothesis.language) else {
                continue
            }

            if language == .chinese,
               let scriptLanguage = stats.preferredChineseLanguage {
                shares[scriptLanguage, default: 0] += hypothesis.confidence
            } else {
                shares[language, default: 0] += hypothesis.confidence
            }
        }

        if stats.kanaCharacters > 0,
           shares.isEmpty,
           let top = hypotheses.first?.confidence {
            shares[.japanese] = min(top, confidenceThreshold)
        }

        let totalShare = shares.values.reduce(0, +)
        guard totalShare > 0 else {
            return [:]
        }

        return shares.mapValues { $0 / totalShare }
    }

    private func selectedLanguages(
        from shares: [SubtitleLanguageCode: Double],
        scriptShares: [SubtitleLanguageCode: Double]
    ) -> Set<SubtitleLanguageCode> {
        var selected = Set<SubtitleLanguageCode>()

        let simplifiedConfidence = shares[.simplifiedChinese] ?? 0
        let traditionalConfidence = shares[.traditionalChinese] ?? 0
        let genericChineseConfidence = shares[.chinese] ?? 0
        let splitChineseConfidence = simplifiedConfidence + traditionalConfidence
        let totalChineseConfidence = splitChineseConfidence + genericChineseConfidence

        if simplifiedConfidence >= confidenceThreshold {
            selected.insert(.simplifiedChinese)
        }
        if traditionalConfidence >= confidenceThreshold {
            selected.insert(.traditionalChinese)
        }
        if genericChineseConfidence >= confidenceThreshold ||
            (splitChineseConfidence >= confidenceThreshold &&
             simplifiedConfidence < confidenceThreshold &&
             traditionalConfidence < confidenceThreshold) {
            selected.insert(.chinese)
        }

        for (language, share) in shares where !language.isChinese && share >= minimumLanguageShare {
            selected.insert(language)
        }

        for (language, share) in scriptShares where share >= minimumLanguageShare {
            if language.isChinese,
               !selected.isDisjoint(with: [.chinese, .simplifiedChinese, .traditionalChinese]) {
                continue
            }
            selected.insert(language)
        }

        if totalChineseConfidence >= minimumLanguageShare,
           selected.isDisjoint(with: [.chinese, .simplifiedChinese, .traditionalChinese]) {
            selected.insert(.chinese)
        }

        return selected
    }

    private func confidence(
        for selected: Set<SubtitleLanguageCode>,
        shares: [SubtitleLanguageCode: Double],
        scriptShares: [SubtitleLanguageCode: Double]
    ) -> Double {
        guard !selected.isEmpty else {
            return 0
        }

        var confidence = 0.0
        if selected.contains(.chinese) {
            confidence += (shares[.chinese] ?? 0)
                + (shares[.simplifiedChinese] ?? 0)
                + (shares[.traditionalChinese] ?? 0)
        } else {
            if selected.contains(.simplifiedChinese) {
                confidence += shares[.simplifiedChinese] ?? 0
            }
            if selected.contains(.traditionalChinese) {
                confidence += shares[.traditionalChinese] ?? 0
            }
        }

        for language in selected where !language.isChinese {
            confidence += max(shares[language] ?? 0, scriptShares[language] ?? 0)
        }

        if selected.contains(.chinese) ||
            selected.contains(.simplifiedChinese) ||
            selected.contains(.traditionalChinese) {
            let scriptChineseConfidence = (scriptShares[.chinese] ?? 0)
                + (scriptShares[.simplifiedChinese] ?? 0)
                + (scriptShares[.traditionalChinese] ?? 0)
            confidence = max(confidence, scriptChineseConfidence)
        }

        return min(confidence, 1)
    }

    private func scriptLanguageShares(
        for candidates: [LanguageCandidate]
    ) -> [SubtitleLanguageCode: Double] {
        var weights: [SubtitleLanguageCode: Double] = [:]
        var totalWeight = 0.0

        for candidate in candidates {
            let stats = candidate.stats
            let weight = Double(stats.effectiveCharacters)
            if stats.kanaCharacters > 0 {
                weights[.japanese, default: 0] += weight
                totalWeight += weight
            } else if stats.hanCharacters > 0,
                      let language = stats.preferredChineseLanguage {
                weights[language, default: 0] += weight
                totalWeight += weight
            } else if stats.latinCharacters > 0 {
                weights[.english, default: 0] += weight
                totalWeight += weight
            }
        }

        guard totalWeight > 0 else {
            return [:]
        }

        return weights.mapValues { $0 / totalWeight }
    }
}

private struct LanguageCandidate {
    let text: String
    let stats: ScriptStats
}

private struct ScriptStats {
    let effectiveCharacters: Int
    let hanCharacters: Int
    let kanaCharacters: Int
    let latinCharacters: Int
    let hangulCharacters: Int
    let simplifiedChineseMarkers: Int
    let traditionalChineseMarkers: Int

    var languageLikeCharacters: Int {
        hanCharacters + kanaCharacters + latinCharacters + hangulCharacters
    }

    var preferredChineseLanguage: SubtitleLanguageCode? {
        if traditionalChineseMarkers > simplifiedChineseMarkers {
            return .traditionalChinese
        }
        if simplifiedChineseMarkers > traditionalChineseMarkers {
            return .simplifiedChinese
        }
        return nil
    }

    init(text: String) {
        var effectiveCharacters = 0
        var hanCharacters = 0
        var kanaCharacters = 0
        var latinCharacters = 0
        var hangulCharacters = 0
        var simplifiedChineseMarkers = 0
        var traditionalChineseMarkers = 0

        for scalar in text.unicodeScalars {
            guard !CharacterSet.whitespacesAndNewlines.contains(scalar) else {
                continue
            }

            let value = scalar.value
            effectiveCharacters += 1

            if Self.isHan(value) {
                hanCharacters += 1
                if Self.simplifiedChineseMarkerScalars.contains(value) {
                    simplifiedChineseMarkers += 1
                }
                if Self.traditionalChineseMarkerScalars.contains(value) {
                    traditionalChineseMarkers += 1
                }
            } else if Self.isKana(value) {
                kanaCharacters += 1
            } else if Self.isLatin(value) {
                latinCharacters += 1
            } else if Self.isHangul(value) {
                hangulCharacters += 1
            }
        }

        self.effectiveCharacters = effectiveCharacters
        self.hanCharacters = hanCharacters
        self.kanaCharacters = kanaCharacters
        self.latinCharacters = latinCharacters
        self.hangulCharacters = hangulCharacters
        self.simplifiedChineseMarkers = simplifiedChineseMarkers
        self.traditionalChineseMarkers = traditionalChineseMarkers
    }

    private static func isHan(_ value: UInt32) -> Bool {
        (0x4E00...0x9FFF).contains(value)
            || (0x3400...0x4DBF).contains(value)
            || (0xF900...0xFAFF).contains(value)
    }

    private static func isKana(_ value: UInt32) -> Bool {
        (0x3040...0x309F).contains(value)
            || (0x30A0...0x30FF).contains(value)
            || (0x31F0...0x31FF).contains(value)
            || (0xFF66...0xFF9D).contains(value)
    }

    private static func isLatin(_ value: UInt32) -> Bool {
        (0x0041...0x005A).contains(value) || (0x0061...0x007A).contains(value)
    }

    private static func isHangul(_ value: UInt32) -> Bool {
        (0xAC00...0xD7AF).contains(value)
            || (0x1100...0x11FF).contains(value)
            || (0x3130...0x318F).contains(value)
    }

    private static let simplifiedChineseMarkerScalars = Set("这个们为学习说话电脑电影字幕风门后龙语".unicodeScalars.map(\.value))
    private static let traditionalChineseMarkerScalars = Set("這個們為學習說話電腦電影字幕風門後龍語".unicodeScalars.map(\.value))
}
