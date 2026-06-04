import Foundation
import NaturalLanguage

public enum SubtitleLanguageCode: String, CaseIterable, Codable, Hashable, Sendable {
    case english = "en"
    case japanese = "ja"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case unknown = "unknown"

    public var isChinese: Bool {
        self == .simplifiedChinese || self == .traditionalChinese
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
    public static let algorithmVersion = 1
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

        var weightedLanguages: [SubtitleLanguageCode: Double] = [:]
        var totalWeight = 0.0

        for candidate in candidates {
            let recognized = recognizedLanguage(for: candidate.text, stats: candidate.stats)
            let weight = Double(candidate.stats.effectiveCharacters) * max(recognized.confidence, 0.2)
            weightedLanguages[recognized.language, default: 0] += weight
            totalWeight += weight
        }

        guard totalWeight > 0 else {
            return .unknown(
                segmentCount: candidates.count,
                effectiveCharacterCount: effectiveCharacterCount
            )
        }

        let distribution = weightedLanguages
            .map { language, weight in
                SubtitleLanguageDistribution(language: language, share: weight / totalWeight)
            }
            .sorted { lhs, rhs in
                if lhs.share == rhs.share {
                    return lhs.language.rawValue < rhs.language.rawValue
                }
                return lhs.share > rhs.share
            }

        let selected = distribution.filter {
            $0.language != .unknown && $0.share >= minimumLanguageShare
        }
        let confidence = selected.reduce(0) { $0 + $1.share }
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
            languages: Set(selected.map(\.language)),
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
        case "zh", "zh-hans", "zh-cn", "zh-sg":
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

    private func recognizedLanguage(
        for text: String,
        stats: ScriptStats
    ) -> (language: SubtitleLanguageCode, confidence: Double) {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 5)
            .map { (language: $0.key.rawValue, confidence: $0.value) }
            .sorted { $0.confidence > $1.confidence }

        if stats.kanaCharacters > 0 {
            let confidence = hypotheses.first(where: { $0.language == SubtitleLanguageCode.japanese.rawValue })?.confidence
                ?? hypotheses.first?.confidence
                ?? confidenceThreshold
            return (.japanese, max(confidence, confidenceThreshold))
        }

        guard let top = hypotheses.first,
              var language = Self.languageCode(forNaturalLanguageIdentifier: top.language)
        else {
            return (.unknown, 0)
        }

        if language.isChinese,
           let scriptLanguage = stats.preferredChineseLanguage {
            language = scriptLanguage
        }

        guard top.confidence >= confidenceThreshold else {
            return (.unknown, top.confidence)
        }

        return (language, top.confidence)
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
