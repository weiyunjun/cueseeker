import Foundation

public enum ASSFontReferenceSource: String, Equatable, Sendable {
    case style
    case inlineOverride
}

public struct ASSFontReferenceIntent: Equatable, Sendable {
    public let fontName: String
    public let source: ASSFontReferenceSource
    public let occurrenceCount: Int
    public let firstOccurrenceOrder: Int

    public init(
        fontName: String,
        source: ASSFontReferenceSource,
        occurrenceCount: Int,
        firstOccurrenceOrder: Int
    ) {
        self.fontName = fontName
        self.source = source
        self.occurrenceCount = occurrenceCount
        self.firstOccurrenceOrder = firstOccurrenceOrder
    }
}

public enum ASSFontIntentExtractor {
    public static let cacheAlgorithmVersion = 1

    public static func references(from contents: String) -> [ASSFontReferenceIntent] {
        Parser(contents: contents).references()
    }

    private struct Parser {
        let contents: String

        func references() -> [ASSFontReferenceIntent] {
            var accumulator = ReferenceAccumulator()
            collectStyleReferences(into: &accumulator)
            collectInlineOverrideReferences(into: &accumulator)
            return accumulator.references()
        }

        private func collectStyleReferences(into accumulator: inout ReferenceAccumulator) {
            var section = Section.unknown
            var styleFormat: [String] = []

            for line in normalizedLines() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let lowercased = trimmed.lowercased()

                if lowercased.hasPrefix("[") && lowercased.hasSuffix("]") {
                    section = Section(rawValue: lowercased) ?? .unknown
                    continue
                }

                guard section == .styles else {
                    continue
                }

                if let body = lineBody(afterPrefix: "format", in: line) {
                    styleFormat = parseFormat(body)
                    continue
                }

                guard let body = lineBody(afterPrefix: "style", in: line),
                      let fontIndex = styleFormat.firstIndex(of: "fontname")
                else {
                    continue
                }

                let fields = splitFields(body)
                guard fields.indices.contains(fontIndex) else {
                    continue
                }

                accumulator.append(fields[fontIndex], source: .style)
            }
        }

        private func collectInlineOverrideReferences(into accumulator: inout ReferenceAccumulator) {
            let script = normalizedContents()
            var searchIndex = script.startIndex

            while let blockStart = script[searchIndex...].firstIndex(of: "{") {
                let bodyStart = script.index(after: blockStart)
                guard let blockEnd = script[bodyStart...].firstIndex(of: "}") else {
                    return
                }

                let body = String(script[bodyStart..<blockEnd])
                collectInlineOverrideReferences(in: body, into: &accumulator)
                searchIndex = script.index(after: blockEnd)
            }
        }

        private func collectInlineOverrideReferences(
            in block: String,
            into accumulator: inout ReferenceAccumulator
        ) {
            var searchIndex = block.startIndex

            while let tagRange = block[searchIndex...].range(of: "\\fn") {
                var nameEnd = tagRange.upperBound
                while nameEnd < block.endIndex {
                    let character = block[nameEnd]
                    if character == "\\" || character == "\n" || character == "\r" {
                        break
                    }
                    nameEnd = block.index(after: nameEnd)
                }

                accumulator.append(
                    String(block[tagRange.upperBound..<nameEnd]),
                    source: .inlineOverride
                )
                searchIndex = nameEnd
            }
        }

        private func normalizedLines() -> [String] {
            normalizedContents()
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
        }

        private func normalizedContents() -> String {
            contents
                .replacingOccurrences(of: "\u{feff}", with: "")
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
        }

        private func parseFormat(_ body: String) -> [String] {
            splitFields(body).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        }

        private func splitFields(_ body: String) -> [String] {
            body.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        }

        private func lineBody(afterPrefix expectedPrefix: String, in line: String) -> String? {
            guard let colon = line.firstIndex(of: ":") else {
                return nil
            }

            let prefix = line[..<colon].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard prefix == expectedPrefix else {
                return nil
            }

            return String(line[line.index(after: colon)...])
        }
    }

    private enum Section: String {
        case styles = "[v4+ styles]"
        case legacyStyles = "[v4 styles]"
        case unknown

        init?(rawValue: String) {
            switch rawValue {
            case Self.styles.rawValue, Self.legacyStyles.rawValue:
                self = .styles
            default:
                self = .unknown
            }
        }
    }

    private struct ReferenceAccumulator {
        private struct Key: Hashable {
            let fontName: String
            let source: ASSFontReferenceSource
        }

        private struct Entry {
            let fontName: String
            let source: ASSFontReferenceSource
            var occurrenceCount: Int
            let firstOccurrenceOrder: Int
        }

        private var entriesByKey: [Key: Entry] = [:]
        private var nextOccurrenceOrder = 0

        mutating func append(_ rawFontName: String, source: ASSFontReferenceSource) {
            let fontName = rawFontName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fontName.isEmpty else {
                return
            }

            let key = Key(fontName: fontName, source: source)
            if var entry = entriesByKey[key] {
                entry.occurrenceCount += 1
                entriesByKey[key] = entry
            } else {
                entriesByKey[key] = Entry(
                    fontName: fontName,
                    source: source,
                    occurrenceCount: 1,
                    firstOccurrenceOrder: nextOccurrenceOrder
                )
            }
            nextOccurrenceOrder += 1
        }

        func references() -> [ASSFontReferenceIntent] {
            entriesByKey.values
                .sorted { lhs, rhs in
                    lhs.firstOccurrenceOrder < rhs.firstOccurrenceOrder
                }
                .map {
                    ASSFontReferenceIntent(
                        fontName: $0.fontName,
                        source: $0.source,
                        occurrenceCount: $0.occurrenceCount,
                        firstOccurrenceOrder: $0.firstOccurrenceOrder
                    )
                }
        }
    }
}
