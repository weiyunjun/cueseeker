import Darwin
import Foundation

actor LocalStreamProxy {
    static let shared = LocalStreamProxy()

    private static let maximumHeaderBytes = 64 * 1024
    private static let maximumTargets = 128

    private var serverSocket: Int32 = -1
    private var port: UInt16 = 0
    private var targets: [String: ProxyTarget] = [:]
    private var targetOrder: [String] = []

    func register(
        remoteURL: URL,
        headers: [String: String],
        cacheKey: String? = nil
    ) throws -> URL {
        try ensureServer()

        let token = Self.makeToken()
        targets[token] = ProxyTarget(remoteURL: remoteURL, headers: headers, cacheKey: cacheKey)
        targetOrder.append(token)
        while targetOrder.count > Self.maximumTargets {
            let expiredToken = targetOrder.removeFirst()
            targets.removeValue(forKey: expiredToken)
        }

        guard let proxyURL = URL(string: "http://127.0.0.1:\(port)/stream/\(token)") else {
            throw LocalStreamProxyError.invalidProxyURL
        }
        return proxyURL
    }

    private func target(for token: String) -> ProxyTarget? {
        targets[token]
    }

    private func ensureServer() throws {
        guard serverSocket < 0 else {
            return
        }

        let socketFD = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            throw LocalStreamProxyError.socketFailed(operation: "socket", errno: errno)
        }

        var reuse: Int32 = 1
        guard Darwin.setsockopt(
            socketFD,
            SOL_SOCKET,
            SO_REUSEADDR,
            &reuse,
            socklen_t(MemoryLayout.size(ofValue: reuse))
        ) == 0 else {
            Darwin.close(socketFD)
            throw LocalStreamProxyError.socketFailed(operation: "setsockopt", errno: errno)
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.bind(socketFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            Darwin.close(socketFD)
            throw LocalStreamProxyError.socketFailed(operation: "bind", errno: errno)
        }

        guard Darwin.listen(socketFD, SOMAXCONN) == 0 else {
            Darwin.close(socketFD)
            throw LocalStreamProxyError.socketFailed(operation: "listen", errno: errno)
        }

        var boundAddress = sockaddr_in()
        var boundAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.getsockname(socketFD, sockaddrPointer, &boundAddressLength)
            }
        }
        guard nameResult == 0 else {
            Darwin.close(socketFD)
            throw LocalStreamProxyError.socketFailed(operation: "getsockname", errno: errno)
        }

        serverSocket = socketFD
        port = UInt16(bigEndian: boundAddress.sin_port)
        Self.startAcceptLoop(socketFD)
    }

    private static func startAcceptLoop(_ serverSocket: Int32) {
        DispatchQueue.global(qos: .userInitiated).async {
            while true {
                var clientAddress = sockaddr_storage()
                var clientAddressLength = socklen_t(MemoryLayout<sockaddr_storage>.size)
                let clientSocket = withUnsafeMutablePointer(to: &clientAddress) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                        Darwin.accept(serverSocket, sockaddrPointer, &clientAddressLength)
                    }
                }

                if clientSocket < 0 {
                    if errno == EINTR {
                        continue
                    }
                    return
                }

                var noSigPipe: Int32 = 1
                _ = Darwin.setsockopt(
                    clientSocket,
                    SOL_SOCKET,
                    SO_NOSIGPIPE,
                    &noSigPipe,
                    socklen_t(MemoryLayout.size(ofValue: noSigPipe))
                )

                Task.detached(priority: .userInitiated) {
                    await handle(clientSocket: clientSocket)
                }
            }
        }
    }

    private nonisolated static func handle(clientSocket: Int32) async {
        defer {
            Darwin.close(clientSocket)
        }

        do {
            let request = try readRequest(from: clientSocket)
            guard request.method == "GET" || request.method == "HEAD" else {
                _ = writeSimpleResponse(
                    statusCode: 405,
                    body: "Method Not Allowed",
                    to: clientSocket
                )
                return
            }

            guard let target = await shared.target(for: request.token) else {
                _ = writeSimpleResponse(statusCode: 404, body: "Not Found", to: clientSocket)
                return
            }

            if request.method == "GET",
               let cacheKey = target.cacheKey,
               let range = RemoteRangeCache.byteRange(from: request.headers["range"]),
               let cachedResponse = await RemoteRangeCache.shared.cachedResponse(cacheKey: cacheKey, range: range) {
                _ = writeAll(
                    responseHeaderData(
                        statusCode: cachedResponse.statusCode,
                        headers: cachedResponse.headers
                    ),
                    to: clientSocket
                ) && writeAll(cachedResponse.data, to: clientSocket)
                return
            }

            try await forward(request: request, target: target, to: clientSocket)
        } catch {
            _ = writeSimpleResponse(statusCode: 502, body: "Bad Gateway", to: clientSocket)
        }
    }

    private nonisolated static func forward(
        request: ProxyRequest,
        target: ProxyTarget,
        to clientSocket: Int32
    ) async throws {
        var remoteRequest = URLRequest(url: target.remoteURL)
        remoteRequest.httpMethod = request.method
        remoteRequest.cachePolicy = .reloadIgnoringLocalCacheData

        for (name, value) in target.headers {
            remoteRequest.setValue(value, forHTTPHeaderField: name)
        }

        for headerName in ProxyRequest.forwardedHeaderNames {
            if let value = request.headers[headerName.lowercased()] {
                remoteRequest.setValue(value, forHTTPHeaderField: headerName)
            }
        }

        if remoteRequest.value(forHTTPHeaderField: "Accept-Encoding") == nil {
            remoteRequest.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 24 * 60 * 60

        let transfer = LocalStreamProxyTransfer(
            clientSocket: clientSocket,
            requestMethod: request.method,
            cacheCapture: ProxyCacheCapture(
                cacheKey: target.cacheKey,
                requestRange: RemoteRangeCache.byteRange(from: request.headers["range"])
            )
        )
        let session = URLSession(
            configuration: configuration,
            delegate: transfer,
            delegateQueue: nil
        )
        let task = session.dataTask(with: remoteRequest)
        task.resume()
        transfer.waitUntilFinished()
        session.invalidateAndCancel()
    }

    private nonisolated static func readRequest(from socket: Int32) throws -> ProxyRequest {
        let terminator = Data([13, 10, 13, 10])
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)

        while buffer.count < maximumHeaderBytes {
            let capacity = chunk.count
            let count = chunk.withUnsafeMutableBytes { rawBuffer in
                Darwin.recv(socket, rawBuffer.baseAddress, capacity, 0)
            }

            if count == 0 {
                throw LocalStreamProxyError.invalidRequest
            }
            if count < 0 {
                if errno == EINTR {
                    continue
                }
                throw LocalStreamProxyError.socketFailed(operation: "recv", errno: errno)
            }

            buffer.append(contentsOf: chunk.prefix(count))
            if let range = buffer.range(of: terminator) {
                let headerData = Data(buffer[..<range.lowerBound])
                guard let headerText = String(data: headerData, encoding: .isoLatin1) else {
                    throw LocalStreamProxyError.invalidRequest
                }
                return try ProxyRequest(headerText: headerText)
            }
        }

        throw LocalStreamProxyError.requestHeaderTooLarge
    }

    private nonisolated static func writeSimpleResponse(
        statusCode: Int,
        body: String,
        to socket: Int32
    ) -> Bool {
        let bodyData = Data(body.utf8)
        var response = "HTTP/1.1 \(statusCode) \(reasonPhrase(for: statusCode))\r\n"
        response += "Content-Type: text/plain; charset=utf-8\r\n"
        response += "Content-Length: \(bodyData.count)\r\n"
        response += "Connection: close\r\n"
        response += "\r\n"
        return writeAll(Data(response.utf8), to: socket)
            && writeAll(bodyData, to: socket)
    }

    fileprivate nonisolated static func writeAll(_ data: Data, to socket: Int32) -> Bool {
        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return true
            }

            var totalSent = 0
            while totalSent < rawBuffer.count {
                let sent = Darwin.send(
                    socket,
                    baseAddress.advanced(by: totalSent),
                    rawBuffer.count - totalSent,
                    0
                )

                if sent > 0 {
                    totalSent += sent
                } else if sent < 0 && errno == EINTR {
                    continue
                } else {
                    return false
                }
            }

            return true
        }
    }

    fileprivate nonisolated static func responseHeaderData(
        statusCode: Int,
        headers: [String: String]
    ) -> Data {
        var response = "HTTP/1.1 \(statusCode) \(reasonPhrase(for: statusCode))\r\n"
        for (name, value) in headers.sorted(by: { $0.key.lowercased() < $1.key.lowercased() }) {
            response += "\(name): \(value)\r\n"
        }
        response += "Connection: close\r\n"
        response += "\r\n"
        return Data(response.utf8)
    }

    private nonisolated static func makeToken() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    private nonisolated static func reasonPhrase(for statusCode: Int) -> String {
        switch statusCode {
        case 200:
            return "OK"
        case 206:
            return "Partial Content"
        case 302:
            return "Found"
        case 400:
            return "Bad Request"
        case 404:
            return "Not Found"
        case 405:
            return "Method Not Allowed"
        case 416:
            return "Range Not Satisfiable"
        case 502:
            return "Bad Gateway"
        default:
            return HTTPURLResponse.localizedString(forStatusCode: statusCode)
        }
    }
}

private struct ProxyTarget: Sendable {
    let remoteURL: URL
    let headers: [String: String]
    let cacheKey: String?
}

private struct ProxyRequest: Sendable {
    static let forwardedHeaderNames = [
        "Range",
        "User-Agent",
        "Accept",
        "Accept-Encoding",
        "If-Modified-Since",
        "If-Range"
    ]

    let method: String
    let token: String
    let headers: [String: String]

    init(headerText: String) throws {
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            throw LocalStreamProxyError.invalidRequest
        }

        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 3 else {
            throw LocalStreamProxyError.invalidRequest
        }

        let method = String(parts[0]).uppercased()
        let requestTarget = String(parts[1])
        let path = requestTarget.split(separator: "?", maxSplits: 1).first.map(String.init) ?? requestTarget
        let pathSegments = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard pathSegments.count == 2,
              pathSegments[0] == "stream",
              !pathSegments[1].isEmpty
        else {
            throw LocalStreamProxyError.invalidRequest
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else {
                continue
            }
            let name = line[..<separator]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty && !value.isEmpty {
                headers[name] = value
            }
        }

        self.method = method
        self.token = pathSegments[1]
        self.headers = headers
    }
}

private struct ProxyCacheCapture: Sendable {
    let cacheKey: String?
    let requestRange: RemoteByteRange?

    var isEligible: Bool {
        cacheKey != nil && requestRange != nil
    }
}

private final class LocalStreamProxyTransfer: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private static let passthroughHeaderNames: Set<String> = [
        "accept-ranges",
        "cache-control",
        "content-length",
        "content-range",
        "content-type",
        "etag",
        "last-modified"
    ]

    private let clientSocket: Int32
    private let requestMethod: String
    private let cacheCapture: ProxyCacheCapture
    private let completion = DispatchSemaphore(value: 0)
    private var didSendResponse = false
    private var responseRange: RemoteByteRange?
    private var responseTotalSize: Int64?
    private var responseContentType: String?
    private var capturedData = Data()
    private var isCaptureAllowed = false

    init(
        clientSocket: Int32,
        requestMethod: String,
        cacheCapture: ProxyCacheCapture
    ) {
        self.clientSocket = clientSocket
        self.requestMethod = requestMethod
        self.cacheCapture = cacheCapture
    }

    func waitUntilFinished() {
        completion.wait()
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }

        if cacheCapture.isEligible,
           httpResponse.statusCode == 206,
           let parsedRange = RemoteRangeCache.responseRange(from: httpResponse.value(forHTTPHeaderField: "Content-Range")),
           parsedRange.range.length <= 16 * 1024 * 1024 {
            responseRange = parsedRange.range
            responseTotalSize = parsedRange.totalSize
            responseContentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
            isCaptureAllowed = true
            capturedData.removeAll(keepingCapacity: true)
        }

        let responseData = LocalStreamProxy.responseHeaderData(
            statusCode: httpResponse.statusCode,
            headers: Self.passthroughHeaders(from: httpResponse)
        )
        guard LocalStreamProxy.writeAll(responseData, to: clientSocket) else {
            completionHandler(.cancel)
            return
        }

        didSendResponse = true
        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        guard requestMethod != "HEAD" else {
            return
        }

        if !LocalStreamProxy.writeAll(data, to: clientSocket) {
            dataTask.cancel()
            isCaptureAllowed = false
            capturedData.removeAll(keepingCapacity: false)
            return
        }

        if isCaptureAllowed {
            capturedData.append(data)
            if capturedData.count > 16 * 1024 * 1024 {
                isCaptureAllowed = false
                capturedData.removeAll(keepingCapacity: false)
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if error == nil,
           isCaptureAllowed,
           let cacheKey = cacheCapture.cacheKey,
           let range = responseRange {
            let data = capturedData
            let totalSize = responseTotalSize
            let contentType = responseContentType
            Task.detached(priority: .utility) {
                await RemoteRangeCache.shared.storeForwardedRange(
                    cacheKey: cacheKey,
                    range: range,
                    totalSize: totalSize,
                    contentType: contentType,
                    data: data
                )
            }
        }

        if error != nil && !didSendResponse {
            _ = LocalStreamProxy.writeAll(
                LocalStreamProxy.responseHeaderData(
                    statusCode: 502,
                    headers: [
                        "Content-Length": "0",
                        "Content-Type": "text/plain; charset=utf-8"
                    ]
                ),
                to: clientSocket
            )
        }
        completion.signal()
    }

    private static func passthroughHeaders(from response: HTTPURLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            let name = String(describing: key)
            if passthroughHeaderNames.contains(name.lowercased()) {
                headers[name] = String(describing: value)
            }
        }
        return headers
    }
}

private enum LocalStreamProxyError: Error, CustomStringConvertible {
    case invalidProxyURL
    case invalidRequest
    case requestHeaderTooLarge
    case socketFailed(operation: String, errno: Int32)

    var description: String {
        switch self {
        case .invalidProxyURL:
            return "Failed to create local stream proxy URL."
        case .invalidRequest:
            return "Local stream proxy received an invalid request."
        case .requestHeaderTooLarge:
            return "Local stream proxy request header is too large."
        case .socketFailed(let operation, let errno):
            return "Local stream proxy socket \(operation) failed with errno \(errno)."
        }
    }
}
