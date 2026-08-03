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
        let data = try Data(contentsOf: subtitleFile, options: .mappedIfSafe)
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
        guard hasValidStructure(contents, format: format) else {
            throw SubtitleTextDecodingError.invalidStructure(format)
        }
        return contents
    }

    private static func hasValidStructure(
        _ contents: String,
        format: SubtitleFormat
    ) -> Bool {
        switch format {
        case .ass:
            var isInsideEvents = false
            var hasEventsSection = false
            var hasEventFormat = false

            for rawLine in contents.split(
                omittingEmptySubsequences: false,
                whereSeparator: { $0.isNewline }
            ) {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                if line.hasPrefix("[") && line.hasSuffix("]") {
                    isInsideEvents = line == "[events]"
                    hasEventsSection = hasEventsSection || isInsideEvents
                } else if isInsideEvents, line.hasPrefix("format:") {
                    hasEventFormat = true
                }
            }
            return hasEventsSection && hasEventFormat

        case .srt:
            return !SRTParser.parseForRendering(contents).isEmpty
        }
    }
}
