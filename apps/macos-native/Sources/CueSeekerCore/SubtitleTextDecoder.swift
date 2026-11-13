import Foundation

public enum SubtitleTextDecodingError: Error, Equatable, Sendable {
    case undecodableData
    case invalidStructure(SubtitleFormat)
}

extension SubtitleTextDecodingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .undecodableData:
            "Subtitle character encoding could not be detected without data loss."
        case .invalidStructure(let format):
            "Decoded subtitle does not contain valid \(format.rawValue.uppercased()) structure."
        }
    }
}

public enum SubtitleTextDecoder {
    public static func decode(
        contentsOf subtitleFile: URL,
        format: SubtitleFormat
    ) throws -> String {
        let data = try WebDAVSubtitleCache.shared.readSubtitleData(from: subtitleFile)
        return try decode(data, format: format)
    }

    public static func decode(
        _ data: Data,
        format: SubtitleFormat
    ) throws -> String {
        try decodeWithEncoding(data, format: format).contents
    }

    public static func decodeWithEncoding(
        _ data: Data,
        format: SubtitleFormat
    ) throws -> (contents: String, encodingName: String) {
        let resolved = try decodeWithResolvedEncoding(data, format: format)
        return (resolved.contents, resolved.encodingName)
    }

    public static func decodeWithResolvedEncoding(
        _ data: Data,
        format: SubtitleFormat
    ) throws -> (contents: String, encodingName: String, encoding: String.Encoding) {
        if let markedEncoding = byteOrderMarkedEncoding(in: data) {
            let encodingName = markedEncodingName(for: markedEncoding.encoding)
            if markedEncoding.encoding == .utf8 {
                let contents: String? = autoreleasepool {
                    guard var decoded = String(data: data.dropFirst(markedEncoding.byteCount), encoding: .utf8) else {
                        return nil
                    }
                    decoded.makeContiguousUTF8()
                    return decoded
                }
                guard let contents else {
                    throw SubtitleTextDecodingError.undecodableData
                }
                return (try validated(contents, format: format), encodingName, .utf8)
            }
            let encodedContents = Data(data.dropFirst(markedEncoding.byteCount))
            guard let contents = String(data: encodedContents, encoding: markedEncoding.encoding),
                  contents.data(using: markedEncoding.encoding) == encodedContents
            else {
                throw SubtitleTextDecodingError.undecodableData
            }
            return (try validated(contents, format: format), encodingName, markedEncoding.encoding)
        }

        let utf8Contents: String? = autoreleasepool {
            guard var decoded = String(data: data, encoding: .utf8) else {
                return nil
            }
            decoded.makeContiguousUTF8()
            return decoded
        }
        if let utf8Contents {
            return (try validated(utf8Contents, format: format), "UTF-8", .utf8)
        }

        let legacyResult: (contents: String, encodingName: String, encoding: String.Encoding)? = autoreleasepool {
            guard var decoded = detectLegacyEncoding(in: data) else {
                return nil
            }
            decoded.contents.makeContiguousUTF8()
            return decoded
        }
        guard let legacyResult else {
            throw SubtitleTextDecodingError.undecodableData
        }
        return (
            try validated(legacyResult.contents, format: format),
            legacyResult.encodingName,
            legacyResult.encoding
        )
    }

    public static func stringEncoding(named encodingName: String) -> String.Encoding? {
        let trimmed = encodingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        switch trimmed.lowercased() {
        case "utf-8", "utf-8 (bom)", "utf8":
            return .utf8
        case "utf-16 le", "utf-16le", "utf16le":
            return .utf16LittleEndian
        case "utf-16 be", "utf-16be", "utf16be":
            return .utf16BigEndian
        case "utf-32 le", "utf-32le", "utf32le":
            return .utf32LittleEndian
        case "utf-32 be", "utf-32be", "utf32be":
            return .utf32BigEndian
        default:
            break
        }
        if let mapped = availableEncodingsByLowercasedName[trimmed.lowercased()] {
            return mapped
        }
        let ianaEncoding = CFStringConvertIANACharSetNameToEncoding(trimmed as CFString)
        if ianaEncoding != kCFStringEncodingInvalidId {
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(ianaEncoding)
            return String.Encoding(rawValue: nsEncoding)
        }
        return nil
    }

    static func leadingByteOrderMarkLength(in data: Data) -> Int {
        byteOrderMarkedEncoding(in: data)?.byteCount ?? 0
    }

    public static func detectedEncodingName(in data: Data) -> String {
        if let markedEncoding = byteOrderMarkedEncoding(in: data) {
            return markedEncodingName(for: markedEncoding.encoding)
        }
        if String(data: data, encoding: .utf8) != nil {
            return "UTF-8"
        }
        if let legacy = detectLegacyEncoding(in: data) {
            return legacy.encodingName
        }
        return "UTF-8"
    }

    private static func markedEncodingName(for encoding: String.Encoding) -> String {
        switch encoding {
        case .utf8:
            return "UTF-8 (BOM)"
        case .utf16BigEndian:
            return "UTF-16 BE"
        case .utf16LittleEndian:
            return "UTF-16 LE"
        case .utf32BigEndian:
            return "UTF-32 BE"
        case .utf32LittleEndian:
            return "UTF-32 LE"
        default:
            return "Unicode"
        }
    }

    private static func byteOrderMarkedEncoding(
        in data: Data
    ) -> (encoding: String.Encoding, byteCount: Int)? {
        if data.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
            return (.utf32BigEndian, 4)
        }
        if data.starts(with: [0xFF, 0xFE, 0x00, 0x00]) {
            return (.utf32LittleEndian, 4)
        }
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return (.utf8, 3)
        }
        if data.starts(with: [0xFE, 0xFF]) {
            return (.utf16BigEndian, 2)
        }
        if data.starts(with: [0xFF, 0xFE]) {
            return (.utf16LittleEndian, 2)
        }
        return nil
    }

    private static let availableEncodingsByLowercasedName: [String: String.Encoding] = {
        var map: [String: String.Encoding] = [:]
        if let encodings = CFStringGetListOfAvailableEncodings() {
            var cursor = encodings
            while cursor.pointee != kCFStringEncodingInvalidId {
                let cfEncoding = cursor.pointee
                cursor = cursor.advanced(by: 1)
                let nsRaw = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
                guard nsRaw != UInt(kCFStringEncodingInvalidId) else {
                    continue
                }
                let encoding = String.Encoding(rawValue: nsRaw)
                if let cfName = CFStringGetNameOfEncoding(cfEncoding) as String? {
                    map[cfName.lowercased()] = encoding
                }
                let localized = String.localizedName(of: encoding)
                if !localized.isEmpty {
                    map[localized.lowercased()] = encoding
                }
            }
        }
        return map
    }()

    private static func detectLegacyEncoding(
        in data: Data
    ) -> (contents: String, encodingName: String, encoding: String.Encoding)? {
        var convertedString: NSString?
        var usedLossyConversion = ObjCBool(false)
        let rawEncoding = NSString.stringEncoding(
            for: data,
            encodingOptions: [.allowLossyKey: false],
            convertedString: &convertedString,
            usedLossyConversion: &usedLossyConversion
        )

        guard rawEncoding != 0,
              !usedLossyConversion.boolValue,
              let convertedString
        else {
            return nil
        }
        let contents = convertedString as String
        let resolvedEncoding = String.Encoding(rawValue: rawEncoding)
        if resolvedEncoding == .utf16 {
            if contents.data(using: .utf16LittleEndian) == data {
                return (contents, "UTF-16 LE", .utf16LittleEndian)
            }
            if contents.data(using: .utf16BigEndian) == data {
                return (contents, "UTF-16 BE", .utf16BigEndian)
            }
        } else if resolvedEncoding == .utf32 {
            if contents.data(using: .utf32LittleEndian) == data {
                return (contents, "UTF-32 LE", .utf32LittleEndian)
            }
            if contents.data(using: .utf32BigEndian) == data {
                return (contents, "UTF-32 BE", .utf32BigEndian)
            }
        }

        let cfEncoding = CFStringConvertNSStringEncodingToEncoding(rawEncoding)
        let encodingName: String
        if let name = CFStringGetNameOfEncoding(cfEncoding) as String? {
            encodingName = name
        } else {
            encodingName = String.localizedName(of: resolvedEncoding)
        }
        return (contents, encodingName, resolvedEncoding)
    }

    private static func validated(
        _ contents: String,
        format: SubtitleFormat
    ) throws -> String {
        // Foundation hands back a lazily bridged string, which would re-materialize
        // its UTF-8 buffer on every byte scan performed by a caller.
        var contents = contents
        contents.makeContiguousUTF8()
        if isBlankSubtitleText(contents) {
            return contents
        }
        guard hasValidStructure(contents, format: format) else {
            throw SubtitleTextDecodingError.invalidStructure(format)
        }
        return contents
    }

    private static func isBlankSubtitleText(_ contents: String) -> Bool {
        !contents.unicodeScalars.contains { scalar in
            !scalar.properties.isWhitespace && scalar != "\u{feff}"
        }
    }

    private static func hasValidStructure(
        _ contents: String,
        format: SubtitleFormat
    ) -> Bool {
        switch format {
        case .ass, .ssa:
            var hasEventsSection = false
            var hasEventFormat = false

            ASSScriptScanner.withScriptBytes(contents) { bytes in
                ASSScriptScanner.scanLines(bytes) { _, kind in
                    switch kind {
                    case .sectionHeader(let isEvents):
                        hasEventsSection = hasEventsSection || isEvents
                    case .eventFormat:
                        hasEventFormat = true
                    case .dialogue, .other:
                        break
                    }
                }
            }
            return hasEventsSection && hasEventFormat

        case .srt, .vtt:
            return SRTParser.hasValidStructure(contents, format: format)
        }
    }
}
