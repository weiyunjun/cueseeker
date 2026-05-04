import CryptoKit
import Foundation

public enum MediaPathDisplay {
    public static func subtitleFileName(for result: SubtitleSearchResult) -> String {
        fileName(sourceRelativePath: result.subtitleSourceRelativePath, path: result.subtitlePath)
    }

    public static func subtitlePath(for result: SubtitleSearchResult) -> String {
        displayPath(sourceRelativePath: result.subtitleSourceRelativePath, path: result.subtitlePath)
    }

    public static func videoPath(for result: SubtitleSearchResult) -> String {
        displayPath(sourceRelativePath: result.videoSourceRelativePath, path: result.videoPath)
    }

    public static func fileName(sourceRelativePath: String?, path: String) -> String {
        if let relativePath = sourceRelativePath?.nilIfEmpty {
            return decodedLastPathComponent(relativePath)
        }

        if let url = URL(string: path), url.scheme != nil {
            return decodedLastPathComponent(url.path)
        }

        return URL(fileURLWithPath: path).lastPathComponent
    }

    public static func displayPath(sourceRelativePath: String?, path: String) -> String {
        if let relativePath = sourceRelativePath?.nilIfEmpty {
            return decoded(relativePath)
        }

        if let url = URL(string: path), url.scheme != nil {
            return decoded(url.path)
        }

        return path
    }

    private static func decodedLastPathComponent(_ path: String) -> String {
        var path = decoded(path)
        if let queryIndex = path.firstIndex(of: "?") {
            path = String(path[..<queryIndex])
        }
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }

        guard let slashIndex = path.lastIndex(of: "/") else {
            return path
        }
        let component = String(path[path.index(after: slashIndex)...])
        return component.isEmpty ? path : component
    }

    private static func decoded(_ value: String) -> String {
        value.removingPercentEncoding ?? value
    }
}

public enum RemoteSubtitleCacheKey {
    public static func fileName(
        sourceID: Int64,
        relativePath: String,
        pathExtension: String
    ) -> String {
        let key = "\(sourceID)\n\(relativePath)"
        let digest = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", Int($0)) }
            .joined()
        let sanitizedExtension = pathExtension
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .nilIfEmpty

        guard let sanitizedExtension else {
            return digest
        }
        return "\(digest).\(sanitizedExtension)"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
