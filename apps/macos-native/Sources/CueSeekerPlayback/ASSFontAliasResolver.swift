import CoreText
import Foundation

struct ASSFontAliasRecord: Sendable {
    let canonicalName: String
    let aliases: [String]

    init(canonicalName: String, aliases: [String]) {
        self.canonicalName = canonicalName
        self.aliases = aliases
    }
}

struct ASSFontAliasTable: Sendable {
    private let replacementsByKey: [String: String]
    let recordCount: Int
    let aliasCount: Int

    init(records: [ASSFontAliasRecord]) {
        var replacementsByKey: [String: String] = [:]
        var recordCount = 0

        for record in records where !record.canonicalName.isEmpty {
            recordCount += 1
            let aliases = ([record.canonicalName] + record.aliases)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            for alias in aliases {
                let key = Self.normalizedKey(alias)
                guard !key.isEmpty, replacementsByKey[key] == nil else {
                    continue
                }
                replacementsByKey[key] = record.canonicalName
            }
        }

        self.replacementsByKey = replacementsByKey
        self.recordCount = recordCount
        self.aliasCount = replacementsByKey.count
    }

    func replacement(for requestedName: String) -> String? {
        let trimmed = requestedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        guard let replacement = replacementsByKey[Self.normalizedKey(trimmed)],
              Self.normalizedKey(replacement) != Self.normalizedKey(trimmed)
        else {
            return nil
        }

        return replacement
    }

    private static func normalizedKey(_ value: String) -> String {
        let folded = (value.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? value)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let ignoredScalars = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "_-"))

        var result = ""
        for scalar in folded.unicodeScalars where !ignoredScalars.contains(scalar) {
            result.unicodeScalars.append(scalar)
        }
        return result
    }
}

struct ASSFontAliasReplacement: Sendable, Equatable {
    enum Location: String, Sendable {
        case style
        case inlineOverride
    }

    let location: Location
    let requestedName: String
    let replacementName: String
}

struct ASSFontAliasRewriteResult: Sendable, Equatable {
    let script: String
    let replacements: [ASSFontAliasReplacement]
}

enum ASSFontAliasRewriter {
    static func rewrite(script: String, aliases: ASSFontAliasTable) -> String {
        rewriteWithReport(script: script, aliases: aliases).script
    }

    static func rewriteWithReport(script: String, aliases: ASSFontAliasTable) -> ASSFontAliasRewriteResult {
        var replacements: [ASSFontAliasReplacement] = []
        let styleRewritten = rewriteStyleFontNames(in: script, aliases: aliases, replacements: &replacements)
        let rewritten = rewriteInlineFontOverrides(in: styleRewritten, aliases: aliases, replacements: &replacements)
        return ASSFontAliasRewriteResult(script: rewritten, replacements: replacements)
    }

    private static func rewriteStyleFontNames(
        in script: String,
        aliases: ASSFontAliasTable,
        replacements: inout [ASSFontAliasReplacement]
    ) -> String {
        var section = ASSSection.unknown
        var styleFormat: [String] = []
        var rewrittenLines: [String] = []
        var changed = false

        for line in script.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = trimmed.lowercased()

            if lowercased.hasPrefix("[") && lowercased.hasSuffix("]") {
                section = ASSSection(rawValue: lowercased) ?? .unknown
                rewrittenLines.append(line)
                continue
            }

            guard section == .styles else {
                rewrittenLines.append(line)
                continue
            }

            if let body = lineBody(afterPrefix: "format", in: line) {
                styleFormat = parseFormat(body)
                rewrittenLines.append(line)
                continue
            }

            guard let body = lineBody(afterPrefix: "style", in: line),
                  let fontIndex = styleFormat.firstIndex(of: "fontname")
            else {
                rewrittenLines.append(line)
                continue
            }

            var fields = splitFields(body)
            guard fields.indices.contains(fontIndex),
                  let replacement = aliases.replacement(for: fields[fontIndex])
            else {
                rewrittenLines.append(line)
                continue
            }

            let requestedName = fields[fontIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            fields[fontIndex] = replacingTrimmedValue(in: fields[fontIndex], with: replacement)
            replacements.append(
                ASSFontAliasReplacement(
                    location: .style,
                    requestedName: requestedName,
                    replacementName: replacement
                )
            )
            let prefix = linePrefix(throughFirstColonIn: line)
            rewrittenLines.append(prefix + fields.joined(separator: ","))
            changed = true
        }

        return changed ? rewrittenLines.joined(separator: "\n") : script
    }

    private static func rewriteInlineFontOverrides(
        in script: String,
        aliases: ASSFontAliasTable,
        replacements: inout [ASSFontAliasReplacement]
    ) -> String {
        var result = ""
        var searchIndex = script.startIndex
        var changed = false

        while let blockStart = script[searchIndex...].firstIndex(of: "{") {
            result.append(contentsOf: script[searchIndex..<blockStart])

            let bodyStart = script.index(after: blockStart)
            guard let blockEnd = script[bodyStart...].firstIndex(of: "}") else {
                result.append(contentsOf: script[blockStart...])
                return changed ? result : script
            }

            let body = String(script[bodyStart..<blockEnd])
            let rewrittenBody = rewriteOverrideBlock(body, aliases: aliases, replacements: &replacements)
            if rewrittenBody != body {
                changed = true
            }

            result.append("{")
            result.append(rewrittenBody)
            result.append("}")
            searchIndex = script.index(after: blockEnd)
        }

        result.append(contentsOf: script[searchIndex...])
        return changed ? result : script
    }

    private static func rewriteOverrideBlock(
        _ block: String,
        aliases: ASSFontAliasTable,
        replacements: inout [ASSFontAliasReplacement]
    ) -> String {
        var result = ""
        var searchIndex = block.startIndex
        var changed = false

        while let tagRange = block[searchIndex...].range(of: "\\fn") {
            result.append(contentsOf: block[searchIndex..<tagRange.upperBound])

            var nameEnd = tagRange.upperBound
            while nameEnd < block.endIndex {
                let character = block[nameEnd]
                if character == "\\" || character == "\n" || character == "\r" {
                    break
                }
                nameEnd = block.index(after: nameEnd)
            }

            let requestedName = String(block[tagRange.upperBound..<nameEnd])
            if let replacement = aliases.replacement(for: requestedName) {
                result.append(replacingTrimmedValue(in: requestedName, with: replacement))
                replacements.append(
                    ASSFontAliasReplacement(
                        location: .inlineOverride,
                        requestedName: requestedName.trimmingCharacters(in: .whitespacesAndNewlines),
                        replacementName: replacement
                    )
                )
                changed = true
            } else {
                result.append(requestedName)
            }

            searchIndex = nameEnd
        }

        result.append(contentsOf: block[searchIndex...])
        return changed ? result : block
    }

    private static func parseFormat(_ body: String) -> [String] {
        splitFields(body).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    private static func splitFields(_ body: String) -> [String] {
        body.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
    }

    private static func lineBody(afterPrefix expectedPrefix: String, in line: String) -> String? {
        guard let colon = line.firstIndex(of: ":") else {
            return nil
        }

        let prefix = line[..<colon].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard prefix == expectedPrefix else {
            return nil
        }

        return String(line[line.index(after: colon)...])
    }

    private static func linePrefix(throughFirstColonIn line: String) -> String {
        guard let colon = line.firstIndex(of: ":") else {
            return ""
        }
        return String(line[...colon])
    }

    private static func replacingTrimmedValue(in original: String, with replacement: String) -> String {
        guard let firstNonWhitespace = original.firstIndex(where: { !$0.isWhitespace }),
              let lastNonWhitespace = original.lastIndex(where: { !$0.isWhitespace })
        else {
            return replacement
        }

        let leading = original[..<firstNonWhitespace]
        let trailing = original[original.index(after: lastNonWhitespace)...]
        return "\(leading)\(replacement)\(trailing)"
    }

    private enum ASSSection: String {
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
}

final class ASSFontAliasResolver: @unchecked Sendable {
    static let shared = ASSFontAliasResolver()

    private let lock = NSLock()
    private var cachedTable: ASSFontAliasTable?

    func rewriteRenderScript(_ script: String) -> String {
        rewriteRenderScript(script, sourceIdentifier: "<unknown>")
    }

    func rewriteRenderScript(_ script: String, sourceIdentifier: String) -> String {
        let result = ASSFontAliasRewriter.rewriteWithReport(script: script, aliases: aliasTable())
        logRewrite(result, sourceIdentifier: sourceIdentifier)
        return result.script
    }

    private func aliasTable() -> ASSFontAliasTable {
        lock.lock()
        defer {
            lock.unlock()
        }

        if let cachedTable {
            return cachedTable
        }

        let table = Self.buildAliasTable()
        cachedTable = table
        print("ASS font alias table built: records=\(table.recordCount) aliases=\(table.aliasCount)")
        return table
    }

    private func logRewrite(_ result: ASSFontAliasRewriteResult, sourceIdentifier: String) {
        guard !result.replacements.isEmpty else {
            print("ASS font alias rewrite: source=\(sourceIdentifier) replacements=0")
            return
        }

        let summary = result.replacements.map {
            "\($0.location.rawValue):\($0.requestedName)->\($0.replacementName)"
        }.joined(separator: ", ")
        print("ASS font alias rewrite: source=\(sourceIdentifier) replacements=\(result.replacements.count) \(summary)")
    }

    private static func buildAliasTable() -> ASSFontAliasTable {
        let options: [CFString: Any] = [
            kCTFontCollectionRemoveDuplicatesOption: true
        ]
        let collection = CTFontCollectionCreateFromAvailableFonts(options as CFDictionary)
        let descriptors = (CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor]) ?? []

        let records = descriptors.compactMap { descriptor -> ASSFontAliasRecord? in
            let postScriptName = stringAttribute(kCTFontNameAttribute, in: descriptor)
            let familyName = stringAttribute(kCTFontFamilyNameAttribute, in: descriptor)
            let displayName = stringAttribute(kCTFontDisplayNameAttribute, in: descriptor)
            let localizedFamilyName = localizedStringAttribute(kCTFontFamilyNameAttribute, in: descriptor)
            let localizedDisplayName = localizedStringAttribute(kCTFontDisplayNameAttribute, in: descriptor)
            let filename = fontFilenameStem(in: descriptor)

            guard let canonicalName = [familyName, displayName, postScriptName].compactMap(\.self).first else {
                return nil
            }

            return ASSFontAliasRecord(
                canonicalName: canonicalName,
                aliases: [
                    postScriptName,
                    familyName,
                    displayName,
                    localizedFamilyName,
                    localizedDisplayName,
                    filename
                ].compactMap(\.self)
            )
        }
        .sorted { lhs, rhs in
            lhs.canonicalName.localizedStandardCompare(rhs.canonicalName) == .orderedAscending
        }

        return ASSFontAliasTable(records: records)
    }

    private static func stringAttribute(_ attribute: CFString, in descriptor: CTFontDescriptor) -> String? {
        let value = CTFontDescriptorCopyAttribute(descriptor, attribute) as? String
        return value?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private static func localizedStringAttribute(_ attribute: CFString, in descriptor: CTFontDescriptor) -> String? {
        let value = CTFontDescriptorCopyLocalizedAttribute(descriptor, attribute, nil) as? String
        return value?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private static func fontFilenameStem(in descriptor: CTFontDescriptor) -> String? {
        guard let url = CTFontDescriptorCopyAttribute(descriptor, kCTFontURLAttribute) as? URL else {
            return nil
        }

        return url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
