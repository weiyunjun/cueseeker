import Foundation

public struct WebDAVFile: Equatable, Sendable {
    public let href: String
    public let relativePath: String
    public let name: String
    public let isDirectory: Bool
    public let size: Int64?
    public let modifiedAt: Date?
}

public enum WebDAVClientError: Error, Equatable, CustomStringConvertible {
    case invalidRootURL(String)
    case invalidFileURL(String)
    case unexpectedStatus(Int)
    case unreadableText(String)

    public var description: String {
        switch self {
        case .invalidRootURL(let value):
            "Invalid WebDAV root URL: \(value)"
        case .invalidFileURL(let value):
            "Invalid WebDAV file URL: \(value)"
        case .unexpectedStatus(let status):
            "Unexpected WebDAV status: \(status)"
        case .unreadableText(let path):
            "Remote subtitle could not be decoded as text: \(path)"
        }
    }
}

public final class WebDAVClient: Sendable {
    public let rootURL: URL

    private let credentials: RemoteMediaSourceCredentials
    private let session: URLSession
    private let rootPath: String
    private let origin: String

    public init(
        rootURL: URL,
        credentials: RemoteMediaSourceCredentials,
        session: URLSession = .shared
    ) throws {
        guard let scheme = rootURL.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              let host = rootURL.host
        else {
            throw WebDAVClientError.invalidRootURL(rootURL.absoluteString)
        }

        self.rootURL = rootURL
        self.credentials = credentials
        self.session = session
        self.rootPath = Self.normalizedRootPath(rootURL.path)

        var origin = "\(scheme)://\(host)"
        if let port = rootURL.port {
            origin += ":\(port)"
        }
        self.origin = origin
    }

    public func listAllFiles() async throws -> [WebDAVFile] {
        var directories = [rootURL]
        var visitedDirectories = Set<String>()
        var files: [WebDAVFile] = []

        while let directory = directories.first {
            directories.removeFirst()

            let directoryKey = directory.absoluteString
            guard !visitedDirectories.contains(directoryKey) else {
                continue
            }
            visitedDirectories.insert(directoryKey)

            let entries = try await propfind(directory)
            for entry in entries where entry.href != normalizedHref(for: directory) {
                if entry.isDirectory {
                    if let url = url(forHref: entry.href) {
                        directories.append(url)
                    }
                } else {
                    files.append(entry)
                }
            }
        }

        return files.sorted { $0.relativePath < $1.relativePath }
    }

    public func downloadText(relativePath: String) async throws -> String {
        let data = try await downloadData(relativePath: relativePath)
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .unicode) {
            return text
        }
        throw WebDAVClientError.unreadableText(relativePath)
    }

    public func downloadData(relativePath: String) async throws -> Data {
        let url = try url(forRelativePath: relativePath)
        return try await data(for: url)
    }

    public func url(for file: WebDAVFile) throws -> URL {
        guard let url = url(forHref: file.href) else {
            throw WebDAVClientError.invalidFileURL(file.href)
        }
        return url
    }

    public func url(forRelativePath relativePath: String) throws -> URL {
        let href = rootPath + Self.percentEncodedPath(relativePath)
        guard let url = url(forHref: href) else {
            throw WebDAVClientError.invalidFileURL(relativePath)
        }
        return url
    }

    private func propfind(_ url: URL) async throws -> [WebDAVFile] {
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        applyBasicAuth(to: &request)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVClientError.unexpectedStatus(-1)
        }
        guard httpResponse.statusCode == 207 else {
            throw WebDAVClientError.unexpectedStatus(httpResponse.statusCode)
        }

        let parser = WebDAVMultiStatusParser(data: data, rootPath: rootPath)
        return try parser.parse()
    }

    private func data(for url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyBasicAuth(to: &request)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVClientError.unexpectedStatus(-1)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw WebDAVClientError.unexpectedStatus(httpResponse.statusCode)
        }
        return data
    }

    private func applyBasicAuth(to request: inout URLRequest) {
        guard !credentials.username.isEmpty || !credentials.password.isEmpty else {
            return
        }

        let userPassword = "\(credentials.username):\(credentials.password)"
        let encoded = Data(userPassword.utf8).base64EncodedString()
        request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
    }

    private func url(forHref href: String) -> URL? {
        if let url = URL(string: href), url.scheme != nil {
            return url
        }

        return URL(string: origin + href)
    }

    private func normalizedHref(for url: URL) -> String {
        var path = url.path.removingPercentEncoding ?? url.path
        path = Self.normalizedRootPath(path)
        if path != "/" {
            path += "/"
        }
        return path
    }

    private static func normalizedRootPath(_ path: String) -> String {
        var path = path.removingPercentEncoding ?? path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path.isEmpty ? "/" : path
    }

    private static func percentEncodedPath(_ path: String) -> String {
        let leadingPath = path.hasPrefix("/") ? path : "/" + path
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "?#"))
        return leadingPath
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { component in
                String(component).addingPercentEncoding(withAllowedCharacters: allowed) ?? String(component)
            }
            .joined(separator: "/")
    }
}

private final class WebDAVMultiStatusParser: NSObject, XMLParserDelegate {
    private let data: Data
    private let rootPath: String
    private var currentElement = ""
    private var currentText = ""
    private var currentHref = ""
    private var currentSize: Int64?
    private var currentModifiedAt: Date?
    private var currentIsDirectory = false
    private var entries: [WebDAVFile] = []
    private var parseError: Error?

    init(data: Data, rootPath: String) {
        self.data = data
        self.rootPath = rootPath
    }

    func parse() throws -> [WebDAVFile] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        guard parser.parse() else {
            throw parser.parserError ?? parseError ?? WebDAVClientError.unexpectedStatus(-1)
        }
        if let parseError {
            throw parseError
        }
        return entries
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = Self.localName(elementName)
        currentElement = name
        currentText = ""
        if name == "response" {
            currentHref = ""
            currentSize = nil
            currentModifiedAt = nil
            currentIsDirectory = false
        } else if name == "collection" {
            currentIsDirectory = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = Self.localName(elementName)
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch name {
        case "href":
            currentHref = value
        case "getcontentlength":
            currentSize = Int64(value)
        case "getlastmodified":
            currentModifiedAt = Self.httpDateFormatter.date(from: value)
        case "response":
            appendCurrentEntry()
        default:
            break
        }

        currentElement = ""
        currentText = ""
    }

    private func appendCurrentEntry() {
        guard !currentHref.isEmpty else {
            return
        }

        let decodedHref = currentHref.removingPercentEncoding ?? currentHref
        let normalizedRoot = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        var relativePath: String
        if decodedHref == rootPath || decodedHref == normalizedRoot {
            relativePath = "/"
        } else if decodedHref.hasPrefix(normalizedRoot) {
            relativePath = String(decodedHref.dropFirst(normalizedRoot.count - 1))
        } else if decodedHref.hasPrefix(rootPath) {
            relativePath = String(decodedHref.dropFirst(rootPath.count))
            if !relativePath.hasPrefix("/") {
                relativePath = "/" + relativePath
            }
        } else {
            relativePath = decodedHref
        }

        if relativePath.count > 1 && relativePath.hasSuffix("/") {
            relativePath.removeLast()
        }

        let name = relativePath == "/"
            ? "/"
            : String(relativePath.split(separator: "/").last ?? "")

        entries.append(
            WebDAVFile(
                href: currentHref,
                relativePath: relativePath,
                name: name,
                isDirectory: currentIsDirectory,
                size: currentSize,
                modifiedAt: currentModifiedAt
            )
        )
    }

    private static func localName(_ name: String) -> String {
        if let index = name.lastIndex(of: ":") {
            return String(name[name.index(after: index)...]).lowercased()
        }
        return name.lowercased()
    }

    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()
}
