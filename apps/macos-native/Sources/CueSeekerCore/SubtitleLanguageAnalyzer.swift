import Foundation

public struct SubtitleLanguageAnalysis: Equatable, Sendable {
    public let format: SubtitleFormat
    public let fileDetection: SubtitleLanguageDetectionResult?
    public let styleDetections: [String: SubtitleLanguageDetectionResult]
    public let cueGroupLanguages: [Set<SubtitleLanguageCode>]

    public init(
        format: SubtitleFormat,
        fileDetection: SubtitleLanguageDetectionResult?,
        styleDetections: [String: SubtitleLanguageDetectionResult],
        cueGroupLanguages: [Set<SubtitleLanguageCode>]
    ) {
        self.format = format
        self.fileDetection = fileDetection
        self.styleDetections = styleDetections
        self.cueGroupLanguages = cueGroupLanguages
    }
}

public struct SubtitleLanguageAnalyzer: Sendable {
    public let recognizer: SubtitleLanguageRecognizer

    public init(recognizer: SubtitleLanguageRecognizer = SubtitleLanguageRecognizer()) {
        self.recognizer = recognizer
    }

    public func analyze(
        format: SubtitleFormat,
        cueGroups: [SubtitleCueGroup]
    ) -> SubtitleLanguageAnalysis {
        switch format {
        case .srt:
            return analyzeSRT(cueGroups: cueGroups)
        case .ass:
            return analyzeASS(cueGroups: cueGroups)
        }
    }

    public static func canonicalASSStyleName(_ styleName: String?) -> String? {
        guard var styleName = styleName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !styleName.isEmpty
        else {
            return nil
        }

        if styleName.hasPrefix("*") {
            styleName.removeFirst()
        }

        return styleName.isEmpty ? nil : styleName
    }

    public static func languageSegments(from content: String) -> [String] {
        content
            .replacingOccurrences(of: "\u{feff}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\h", with: " ")
            .components(separatedBy: .newlines)
            .compactMap { rawSegment in
                let segment = rawSegment
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !segment.isEmpty,
                      !isLikelyASSDrawingResidual(segment)
                else {
                    return nil
                }
                return segment
            }
    }

    private func analyzeSRT(cueGroups: [SubtitleCueGroup]) -> SubtitleLanguageAnalysis {
        let segments = cueGroups.flatMap { Self.languageSegments(from: $0.searchContent) }
        let detection = recognizer.detectLanguages(in: segments)
        let languages = Self.normalizedLanguageSet(detection.languages)
        return SubtitleLanguageAnalysis(
            format: .srt,
            fileDetection: detection,
            styleDetections: [:],
            cueGroupLanguages: Array(repeating: languages, count: cueGroups.count)
        )
    }

    private func analyzeASS(cueGroups: [SubtitleCueGroup]) -> SubtitleLanguageAnalysis {
        var usedStyles: [String] = []
        var seenStyles = Set<String>()
        var segmentsByStyle: [String: [String]] = [:]

        for group in cueGroups {
            for line in group.cueLines {
                guard line.sourceFormat == .ass,
                      let styleName = Self.canonicalASSStyleName(line.sourceStyle)
                else {
                    continue
                }

                if seenStyles.insert(styleName).inserted {
                    usedStyles.append(styleName)
                }
                segmentsByStyle[styleName, default: []].append(
                    contentsOf: Self.languageSegments(from: line.content)
                )
            }
        }

        var styleDetections: [String: SubtitleLanguageDetectionResult] = [:]
        for styleName in usedStyles {
            styleDetections[styleName] = recognizer.detectLanguages(in: segmentsByStyle[styleName] ?? [])
        }

        let cueGroupLanguages = cueGroups.map { group in
            var languages = Set<SubtitleLanguageCode>()

            for line in group.cueLines {
                if let styleName = Self.canonicalASSStyleName(line.sourceStyle) {
                    languages.formUnion(styleDetections[styleName]?.languages ?? [.unknown])
                } else if !Self.languageSegments(from: line.content).isEmpty {
                    languages.insert(.unknown)
                }
            }

            return Self.normalizedLanguageSet(languages)
        }

        return SubtitleLanguageAnalysis(
            format: .ass,
            fileDetection: nil,
            styleDetections: styleDetections,
            cueGroupLanguages: cueGroupLanguages
        )
    }

    private static func normalizedLanguageSet(_ languages: Set<SubtitleLanguageCode>) -> Set<SubtitleLanguageCode> {
        let knownLanguages = languages.filter { $0 != .unknown }
        return knownLanguages.isEmpty ? [.unknown] : knownLanguages
    }

    private static func isLikelyASSDrawingResidual(_ segment: String) -> Bool {
        let tokens = segment
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .map(String.init)
        guard !tokens.isEmpty else {
            return false
        }

        let drawingCommands: Set<String> = ["m", "n", "l", "b", "s", "p", "c"]
        var hasDrawingCommand = false
        for token in tokens {
            if drawingCommands.contains(token) {
                hasDrawingCommand = true
                continue
            }
            if Double(token) != nil {
                continue
            }
            return false
        }

        return hasDrawingCommand
    }
}
