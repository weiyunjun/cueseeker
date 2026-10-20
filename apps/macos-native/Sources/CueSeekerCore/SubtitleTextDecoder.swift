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
        if let markedEncoding = byteOrderMarkedEncoding(in: data) {
            let encodedContents = Data(data.dropFirst(markedEncoding.byteCount))
            guard let contents = String(data: encodedContents, encoding: markedEncoding.encoding),
                  contents.data(using: markedEncoding.encoding) == encodedContents
            else {
                throw SubtitleTextDecodingError.undecodableData
            }
            return try validated(contents, format: format)
        }

        if let contents = String(data: data, encoding: .utf8) {
            return try validated(contents, format: format)
        }

        guard let contents = detectLegacyEncoding(in: data) else {
            throw SubtitleTextDecodingError.undecodableData
        }
        return try validated(contents, format: format)
    }

    public static func detectedEncodingName(in data: Data) -> String {
        if let markedEncoding = byteOrderMarkedEncoding(in: data) {
            switch markedEncoding.encoding {
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
        if String(data: data, encoding: .utf8) != nil {
            return "UTF-8"
        }
        var convertedString: NSString?
        var usedLossyConversion = ObjCBool(false)
        let rawEncoding = NSString.stringEncoding(
            for: data,
            encodingOptions: [.allowLossyKey: false],
            convertedString: &convertedString,
            usedLossyConversion: &usedLossyConversion
        )
        if rawEncoding != 0, !usedLossyConversion.boolValue {
            let cfEncoding = CFStringConvertNSStringEncodingToEncoding(rawEncoding)
            if let name = CFStringGetNameOfEncoding(cfEncoding) as String? {
                return name
            }
            return String.localizedName(of: String.Encoding(rawValue: rawEncoding))
        }
        return "UTF-8"
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

    private static func detectLegacyEncoding(in data: Data) -> String? {
        var convertedString: NSString?
        var usedLossyConversion = ObjCBool(false)
        let encoding = NSString.stringEncoding(
            for: data,
            encodingOptions: [.allowLossyKey: false],
            convertedString: &convertedString,
            usedLossyConversion: &usedLossyConversion
        )

        guard encoding != 0,
              !usedLossyConversion.boolValue,
              let convertedString
        else {
            return nil
        }
        return convertedString as String
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
        contents
            .replacingOccurrences(of: "\u{feff}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    private static func hasValidStructure(
        _ contents: String,
        format: SubtitleFormat
    ) -> Bool {
        switch format {
        case .ass:
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
