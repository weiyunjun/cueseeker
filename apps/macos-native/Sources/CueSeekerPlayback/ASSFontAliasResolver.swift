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

    init(records: [ASSFontAliasRecord]) {
        var replacementsByKey: [String: String] = [:]

        for record in records where !record.canonicalName.isEmpty {
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

    static func normalizedKey(_ value: String) -> String {
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

struct ASSFontNameTableFace: Codable, Equatable, Sendable {
    let aliases: [String]
    let postScriptNames: [String]
    let postScriptKeys: Set<String>
}

struct ASSInstalledFontFileSnapshot: Codable, Equatable, Sendable {
    let path: String
    let fileSize: Int64
    let modificationTimeNanoseconds: Int64

    var url: URL {
        URL(fileURLWithPath: path).standardizedFileURL
    }
}

struct ASSInstalledFontEnvironmentSnapshot: Codable, Equatable, Sendable {
    let entries: [ASSInstalledFontFileSnapshot]
}

enum ASSFontAliasEnvironmentCache {
    static let algorithmVersion = 2

    private struct Payload: Codable {
        let algorithmVersion: Int
        let snapshot: ASSInstalledFontEnvironmentSnapshot
        let facesByPath: [String: [ASSFontNameTableFace]]
    }

    static func cachedFaces(
        matching snapshot: ASSInstalledFontEnvironmentSnapshot,
        cacheURL: URL = defaultCacheURL()
    ) throws -> [URL: [ASSFontNameTableFace]]? {
        let data = try Data(contentsOf: cacheURL)
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.algorithmVersion == algorithmVersion,
              payload.snapshot == snapshot
        else {
            return nil
        }

        return Dictionary(uniqueKeysWithValues: payload.facesByPath.map { path, faces in
            (URL(fileURLWithPath: path).standardizedFileURL, faces)
        })
    }

    static func store(
        facesByURL: [URL: [ASSFontNameTableFace]],
        snapshot: ASSInstalledFontEnvironmentSnapshot,
        cacheURL: URL = defaultCacheURL()
    ) throws {
        let payload = Payload(
            algorithmVersion: algorithmVersion,
            snapshot: snapshot,
            facesByPath: Dictionary(uniqueKeysWithValues: facesByURL.map { url, faces in
                (url.standardizedFileURL.path, faces)
            })
        )
        let data = try JSONEncoder().encode(payload)
        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: cacheURL, options: .atomic)
    }

    static func defaultCacheURL() -> URL {
        let baseDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches")

        return baseDirectory
            .appendingPathComponent("CueSeeker", isDirectory: true)
            .appendingPathComponent("ASSFontAliasResolver", isDirectory: true)
            .appendingPathComponent("font-environment-v\(algorithmVersion).json")
    }
}

enum ASSFontNameTableParser {
    private static let supportedNameIDs: Set<UInt16> = [1, 2, 4, 6, 16, 17, 18, 21, 22]
    private static let postScriptNameID: UInt16 = 6
    private static let maximumFaceCount = 256
    private static let maximumTableCount = 512

    static func aliases(in data: Data, matchingPostScriptName postScriptName: String?) -> [String] {
        aliases(in: faces(in: data), matchingPostScriptName: postScriptName)
    }

    static func aliases(in faces: [ASSFontNameTableFace], matchingPostScriptName postScriptName: String?) -> [String] {
        guard !faces.isEmpty else {
            return []
        }

        let postScriptKey = postScriptName.map(ASSFontAliasTable.normalizedKey)
        if let postScriptKey, !postScriptKey.isEmpty,
           let matchingFace = faces.first(where: { $0.postScriptKeys.contains(postScriptKey) }) {
            return matchingFace.aliases
        }

        return faces.count == 1 ? faces[0].aliases : []
    }

    static func faces(in data: Data) -> [ASSFontNameTableFace] {
        faceOffsets(in: data).compactMap { parseFace(in: data, at: $0) }
    }

    private static func faceOffsets(in data: Data) -> [Int] {
        guard let version = data.uint32BigEndian(at: 0) else {
            return []
        }

        if version == sfntTag("ttcf") {
            guard let faceCount = data.uint32BigEndian(at: 8),
                  faceCount > 0,
                  faceCount <= maximumFaceCount
            else {
                return []
            }

            return (0..<Int(faceCount)).compactMap { index in
                data.uint32BigEndian(at: 12 + index * 4).map(Int.init)
            }
        }

        return isFontVersion(version) ? [0] : []
    }

    private static func parseFace(in data: Data, at faceOffset: Int) -> ASSFontNameTableFace? {
        guard let version = data.uint32BigEndian(at: faceOffset),
              isFontVersion(version),
              let tableCount = data.uint16BigEndian(at: faceOffset + 4),
              tableCount > 0,
              tableCount <= maximumTableCount
        else {
            return nil
        }

        let directoryOffset = faceOffset + 12
        for tableIndex in 0..<Int(tableCount) {
            let recordOffset = directoryOffset + tableIndex * 16
            guard let tag = data.uint32BigEndian(at: recordOffset) else {
                continue
            }

            guard tag == sfntTag("name"),
                  let tableOffset = data.uint32BigEndian(at: recordOffset + 8),
                  let tableLength = data.uint32BigEndian(at: recordOffset + 12)
            else {
                continue
            }

            return parseNameTable(in: data, offset: Int(tableOffset), length: Int(tableLength))
        }

        return nil
    }

    private static func parseNameTable(in data: Data, offset: Int, length: Int) -> ASSFontNameTableFace? {
        guard length >= 6,
              offset >= 0,
              offset + length <= data.count,
              let count = data.uint16BigEndian(at: offset + 2),
              let stringOffset = data.uint16BigEndian(at: offset + 4)
        else {
            return nil
        }

        let recordStart = offset + 6
        let storageStart = offset + Int(stringOffset)
        guard recordStart + Int(count) * 12 <= offset + length,
              storageStart <= offset + length
        else {
            return nil
        }

        var aliases: [String] = []
        var seenAliasKeys = Set<String>()
        var postScriptNames: [String] = []
        var seenPostScriptKeys = Set<String>()
        var postScriptKeys = Set<String>()

        for index in 0..<Int(count) {
            let recordOffset = recordStart + index * 12
            guard let platformID = data.uint16BigEndian(at: recordOffset),
                  let encodingID = data.uint16BigEndian(at: recordOffset + 2),
                  let nameID = data.uint16BigEndian(at: recordOffset + 6),
                  let stringLength = data.uint16BigEndian(at: recordOffset + 8),
                  let nameOffset = data.uint16BigEndian(at: recordOffset + 10),
                  supportedNameIDs.contains(nameID)
            else {
                continue
            }

            let stringStart = storageStart + Int(nameOffset)
            let stringEnd = stringStart + Int(stringLength)
            guard stringStart >= storageStart,
                  stringEnd <= offset + length,
                  let stringData = data.subdataIfAvailable(in: stringStart..<stringEnd),
                  let name = decodeNameString(stringData, platformID: platformID, encodingID: encodingID)
            else {
                continue
            }

            appendUnique(name, to: &aliases, seenKeys: &seenAliasKeys)
            if nameID == postScriptNameID {
                let key = ASSFontAliasTable.normalizedKey(name)
                if !key.isEmpty {
                    postScriptKeys.insert(key)
                }
                appendUnique(name, to: &postScriptNames, seenKeys: &seenPostScriptKeys)
            }
        }

        guard !aliases.isEmpty else {
            return nil
        }

        return ASSFontNameTableFace(
            aliases: aliases,
            postScriptNames: postScriptNames,
            postScriptKeys: postScriptKeys
        )
    }

    private static func decodeNameString(_ data: Data, platformID: UInt16, encodingID: UInt16) -> String? {
        let encoding: String.Encoding?
        switch platformID {
        case 0:
            encoding = .utf16BigEndian
        case 1:
            encoding = macStringEncoding(for: encodingID)
        case 2:
            encoding = encodingID == 0 ? .ascii : nil
        case 3:
            encoding = .utf16BigEndian
        default:
            encoding = nil
        }

        return encoding
            .flatMap { String(data: data, encoding: $0) }
            .map { $0.replacingOccurrences(of: "\0", with: "") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap(\.nilIfEmpty)
    }

    private static func macStringEncoding(for encodingID: UInt16) -> String.Encoding? {
        let cfEncoding: CFStringEncoding
        switch encodingID {
        case 0:
            cfEncoding = CFStringEncoding(CFStringBuiltInEncodings.macRoman.rawValue)
        case 1:
            cfEncoding = CFStringEncoding(CFStringEncodings.macJapanese.rawValue)
        case 2:
            cfEncoding = CFStringEncoding(CFStringEncodings.macChineseTrad.rawValue)
        case 3:
            cfEncoding = CFStringEncoding(CFStringEncodings.macKorean.rawValue)
        case 25:
            cfEncoding = CFStringEncoding(CFStringEncodings.macChineseSimp.rawValue)
        default:
            return nil
        }

        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        guard nsEncoding != UInt(kCFStringEncodingInvalidId) else {
            return nil
        }

        return String.Encoding(rawValue: nsEncoding)
    }

    private static func appendUnique(_ value: String, to values: inout [String], seenKeys: inout Set<String>) {
        let key = ASSFontAliasTable.normalizedKey(value)
        guard !key.isEmpty, !seenKeys.contains(key) else {
            return
        }

        seenKeys.insert(key)
        values.append(value)
    }

    private static func isFontVersion(_ value: UInt32) -> Bool {
        value == 0x0001_0000
            || value == sfntTag("OTTO")
            || value == sfntTag("true")
            || value == sfntTag("typ1")
    }

    private static func sfntTag(_ tag: String) -> UInt32 {
        tag.utf8.reduce(UInt32(0)) { result, byte in
            (result << 8) | UInt32(byte)
        }
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

enum ASSFontAliasRewritePlanner {
    static func shouldRewriteScript(requestedFontNames: [String]?, aliases: ASSFontAliasTable) -> Bool {
        guard let requestedFontNames else {
            return true
        }

        return requestedFontNames.contains { aliases.replacement(for: $0) != nil }
    }
}

enum ASSFontAliasRewriter {
    static func rewrite(script: String, aliases: ASSFontAliasTable) -> String {
        rewriteWithReport(script: script, aliases: aliases).script
    }

    static func rewriteWithReport(script: String, aliases: ASSFontAliasTable) -> ASSFontAliasRewriteResult {
        var replacements: [ASSFontAliasReplacement] = []
        let normalizedScript = normalizeLineEndings(script)
        let styleRewritten = rewriteStyleFontNames(in: normalizedScript, aliases: aliases, replacements: &replacements)
        let rewritten = rewriteInlineFontOverrides(in: styleRewritten, aliases: aliases, replacements: &replacements)
        return ASSFontAliasRewriteResult(
            script: replacements.isEmpty ? script : rewritten,
            replacements: replacements
        )
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

    private static func normalizeLineEndings(_ script: String) -> String {
        script
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
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
    private var cachedTable: (snapshot: ASSInstalledFontEnvironmentSnapshot, table: ASSFontAliasTable)?

    func rewriteRenderScript(_ script: String, requestedFontNames: [String]? = nil) -> String {
        let aliases = aliasTable()
        guard ASSFontAliasRewritePlanner.shouldRewriteScript(
            requestedFontNames: requestedFontNames,
            aliases: aliases
        ) else {
            return script
        }

        return ASSFontAliasRewriter.rewrite(script: script, aliases: aliases)
    }

    private func aliasTable() -> ASSFontAliasTable {
        let installedFontSnapshot = Self.installedFontEnvironmentSnapshot()

        lock.lock()
        if let cachedTable, cachedTable.snapshot == installedFontSnapshot {
            lock.unlock()
            return cachedTable.table
        }
        lock.unlock()

        let table = Self.buildAliasTable(for: installedFontSnapshot)

        lock.lock()
        cachedTable = (snapshot: installedFontSnapshot, table: table)
        lock.unlock()
        return table
    }

    private static func buildAliasTable(for installedFontSnapshot: ASSInstalledFontEnvironmentSnapshot) -> ASSFontAliasTable {
        let installedFontFacesByURL = installedFontFacesByURL(for: installedFontSnapshot)
        let options: [CFString: Any] = [
            kCTFontCollectionRemoveDuplicatesOption: true
        ]
        let collection = CTFontCollectionCreateFromAvailableFonts(options as CFDictionary)
        let descriptors = (CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor]) ?? []
        let descriptorURLs = Set(descriptors.compactMap(fontURL(in:)))

        let records = descriptors.compactMap { descriptor -> ASSFontAliasRecord? in
            let postScriptName = stringAttribute(kCTFontNameAttribute, in: descriptor)
            let familyName = stringAttribute(kCTFontFamilyNameAttribute, in: descriptor)
            let displayName = stringAttribute(kCTFontDisplayNameAttribute, in: descriptor)
            let localizedFamilyName = localizedStringAttribute(kCTFontFamilyNameAttribute, in: descriptor)
            let localizedDisplayName = localizedStringAttribute(kCTFontDisplayNameAttribute, in: descriptor)
            let filename = fontFilenameStem(in: descriptor)
            let fontFileAliases = fontFileAliases(
                in: descriptor,
                matchingPostScriptName: postScriptName,
                facesByURL: installedFontFacesByURL
            )

            guard let canonicalName = canonicalName(
                candidates: [familyName, displayName, postScriptName],
                fontFileAliases: fontFileAliases
            ) else {
                return nil
            }

            return ASSFontAliasRecord(
                canonicalName: canonicalName,
                aliases: ([
                    postScriptName,
                    familyName,
                    displayName,
                    localizedFamilyName,
                    localizedDisplayName,
                    filename
                ].compactMap(\.self) + fontFileAliases)
            )
        } + installedFontRecords(
            facesByURL: installedFontFacesByURL,
            excluding: descriptorURLs
        )
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
        guard let url = fontURL(in: descriptor) else {
            return nil
        }

        return url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    static func canonicalName(candidates: [String?], fontFileAliases: [String]) -> String? {
        let parsedAliasKeys = Set(fontFileAliases.map(ASSFontAliasTable.normalizedKey).filter { !$0.isEmpty })
        let resolvedCandidates = candidates.compactMap(\.self)

        if !parsedAliasKeys.isEmpty,
           let parsedCanonical = resolvedCandidates.first(where: {
               parsedAliasKeys.contains(ASSFontAliasTable.normalizedKey($0))
           }) {
            return parsedCanonical
        }

        return resolvedCandidates.first
    }

    private static func fontFileAliases(
        in descriptor: CTFontDescriptor,
        matchingPostScriptName postScriptName: String?,
        facesByURL: [URL: [ASSFontNameTableFace]]
    ) -> [String] {
        guard let url = fontURL(in: descriptor),
              let faces = facesByURL[url]
        else {
            return []
        }

        return ASSFontNameTableParser.aliases(in: faces, matchingPostScriptName: postScriptName)
    }

    private static func installedFontRecords(
        facesByURL: [URL: [ASSFontNameTableFace]],
        excluding descriptorURLs: Set<URL>
    ) -> [ASSFontAliasRecord] {
        facesByURL.flatMap { url, faces -> [ASSFontAliasRecord] in
            guard !descriptorURLs.contains(url) else {
                return []
            }

            let filename = url.deletingPathExtension().lastPathComponent
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
            return faces.compactMap { face in
                guard let canonicalName = face.postScriptNames.first ?? face.aliases.first else {
                    return nil
                }

                return ASSFontAliasRecord(
                    canonicalName: canonicalName,
                    aliases: face.aliases + [filename].compactMap(\.self)
                )
            }
        }
    }

    private static func installedFontFacesByURL(
        for snapshot: ASSInstalledFontEnvironmentSnapshot
    ) -> [URL: [ASSFontNameTableFace]] {
        registerInstalledFonts(at: snapshot.entries.map(\.url))

        if let cachedFaces = try? ASSFontAliasEnvironmentCache.cachedFaces(matching: snapshot) {
            return cachedFaces
        }

        let facesByURL = parseInstalledFontFaces(in: snapshot)
        try? ASSFontAliasEnvironmentCache.store(facesByURL: facesByURL, snapshot: snapshot)
        return facesByURL
    }

    private static func parseInstalledFontFaces(
        in snapshot: ASSInstalledFontEnvironmentSnapshot
    ) -> [URL: [ASSFontNameTableFace]] {
        var facesByURL: [URL: [ASSFontNameTableFace]] = [:]
        for entry in snapshot.entries {
            let fontURL = entry.url
            guard facesByURL[fontURL] == nil,
                  let data = try? Data(contentsOf: fontURL, options: [.mappedIfSafe])
            else {
                continue
            }

            let faces = ASSFontNameTableParser.faces(in: data)
            if !faces.isEmpty {
                facesByURL[fontURL] = faces
            }
        }

        return facesByURL
    }

    static func installedFontEnvironmentSnapshot(
        directories: [URL] = installedFontDirectories()
    ) -> ASSInstalledFontEnvironmentSnapshot {
        var entries: [ASSInstalledFontFileSnapshot] = []
        let supportedExtensions: Set<String> = ["otc", "otf", "ttc", "ttf"]

        for directory in directories {
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                let fontURL = url.standardizedFileURL
                guard supportedExtensions.contains(fontURL.pathExtension.lowercased()),
                      let values = try? fontURL.resourceValues(
                        forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
                      ),
                      values.isRegularFile == true
                else {
                    continue
                }

                let modificationTimeNanoseconds = Int64(
                    ((values.contentModificationDate?.timeIntervalSince1970 ?? 0) * 1_000_000_000).rounded()
                )
                entries.append(
                    ASSInstalledFontFileSnapshot(
                        path: fontURL.path,
                        fileSize: Int64(values.fileSize ?? 0),
                        modificationTimeNanoseconds: modificationTimeNanoseconds
                    )
                )
            }
        }

        return ASSInstalledFontEnvironmentSnapshot(
            entries: entries.sorted { lhs, rhs in
                lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            }
        )
    }

    static func installedFontDirectories() -> [URL] {
        var directories: [URL] = []
        if let userLibrary = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            directories.append(userLibrary.appendingPathComponent("Fonts", isDirectory: true))
        }
        directories.append(URL(fileURLWithPath: "/Library/Fonts", isDirectory: true))
        directories.append(URL(fileURLWithPath: "/Network/Library/Fonts", isDirectory: true))
        return directories
    }

    private static func registerInstalledFonts(at urls: [URL]) {
        for url in urls {
            registerFontForCurrentProcess(at: url)
        }
    }

    private static func registerFontForCurrentProcess(at url: URL) {
        var error: Unmanaged<CFError>?
        _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if let error {
            _ = error.takeRetainedValue()
        }
    }

    private static func fontURL(in descriptor: CTFontDescriptor) -> URL? {
        (CTFontDescriptorCopyAttribute(descriptor, kCTFontURLAttribute) as? URL)?.standardizedFileURL
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension Data {
    func uint16BigEndian(at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= count else {
            return nil
        }

        return (UInt16(self[offset]) << 8) | UInt16(self[offset + 1])
    }

    func uint32BigEndian(at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else {
            return nil
        }

        return (UInt32(self[offset]) << 24)
            | (UInt32(self[offset + 1]) << 16)
            | (UInt32(self[offset + 2]) << 8)
            | UInt32(self[offset + 3])
    }

    func subdataIfAvailable(in range: Range<Int>) -> Data? {
        guard range.lowerBound >= 0,
              range.upperBound <= count,
              range.lowerBound <= range.upperBound
        else {
            return nil
        }

        return subdata(in: range)
    }
}
