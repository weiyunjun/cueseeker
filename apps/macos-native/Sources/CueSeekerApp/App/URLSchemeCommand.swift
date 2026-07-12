import Foundation

enum URLSchemeCommand: Equatable, Sendable {
    case search(keyword: String)

    init?(urlString: String) {
        guard Self.hasValidPercentEncoding(urlString),
              let components = URLComponents(string: urlString),
              components.scheme?.lowercased() == "cueseeker",
              components.host?.lowercased() == "search",
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil,
              components.percentEncodedPath.isEmpty || components.percentEncodedPath == "/",
              let queryItems = components.queryItems,
              queryItems.count == 1,
              queryItems[0].name == "q",
              let value = queryItems[0].value
        else {
            return nil
        }

        let keyword = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return nil
        }
        self = .search(keyword: keyword)
    }

    private static func hasValidPercentEncoding(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        var index = 0
        while index < bytes.count {
            guard bytes[index] == 0x25 else {
                index += 1
                continue
            }
            guard index + 2 < bytes.count,
                  bytes[index + 1].isASCIIHexDigit,
                  bytes[index + 2].isASCIIHexDigit
            else {
                return false
            }
            index += 3
        }
        return true
    }
}

private extension UInt8 {
    var isASCIIHexDigit: Bool {
        (0x30...0x39).contains(self)
            || (0x41...0x46).contains(self)
            || (0x61...0x66).contains(self)
    }
}
