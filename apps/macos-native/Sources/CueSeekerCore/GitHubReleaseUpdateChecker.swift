import Foundation

/// Compares semantic version strings and evaluates GitHub Latest Release API responses.
public enum GitHubReleaseUpdateChecker {
    public static let repositoryURL = URL(string: "https://github.com/weiyunjun/cueseeker")!
    public static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/weiyunjun/cueseeker/releases/latest")!

    public enum CheckResult: Equatable, Sendable {
        case upToDate
        case updateAvailable(version: String, releaseURL: URL)
        case failed
    }

    public struct SemanticVersion: Comparable, Equatable, Sendable {
        public let segments: [Int]

        /// Parses a numeric dot-separated version string with an optional leading `v` or `V`.
        public init?(string: String) {
            var trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
                trimmed.removeFirst()
            }
            guard !trimmed.isEmpty else {
                return nil
            }
            let rawSegments = trimmed.split(separator: ".", omittingEmptySubsequences: false)
            guard !rawSegments.isEmpty else {
                return nil
            }
            var parsed: [Int] = []
            parsed.reserveCapacity(rawSegments.count)
            for segment in rawSegments {
                guard !segment.isEmpty,
                      segment.allSatisfy({ $0 >= "0" && $0 <= "9" }),
                      let value = Int(segment)
                else {
                    return nil
                }
                parsed.append(value)
            }
            self.segments = parsed
        }

        /// Canonical `vX.Y.Z` string formatted from parsed numeric segments.
        public var normalizedTagString: String {
            "v" + segments.map(String.init).joined(separator: ".")
        }

        public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
            let count = max(lhs.segments.count, rhs.segments.count)
            for index in 0..<count {
                let left = index < lhs.segments.count ? lhs.segments[index] : 0
                let right = index < rhs.segments.count ? rhs.segments[index] : 0
                if left != right {
                    return left < right
                }
            }
            return false
        }

        public static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
            let count = max(lhs.segments.count, rhs.segments.count)
            for index in 0..<count {
                let left = index < lhs.segments.count ? lhs.segments[index] : 0
                let right = index < rhs.segments.count ? rhs.segments[index] : 0
                if left != right {
                    return false
                }
            }
            return true
        }
    }

    private struct ReleasePayload: Decodable {
        let tagName: String?
        let htmlURL: String?
        let draft: Bool?
        let prerelease: Bool?

        private enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case draft
            case prerelease
        }
    }

    /// Evaluates a GitHub `/releases/latest` HTTP response against `currentVersion`.
    public static func evaluateResponse(
        statusCode: Int,
        data: Data,
        currentVersion: String
    ) -> CheckResult {
        if statusCode == 404 {
            return .upToDate
        }
        guard statusCode == 200 else {
            return .failed
        }
        guard let payload = try? JSONDecoder().decode(ReleasePayload.self, from: data) else {
            return .failed
        }
        if payload.draft == true || payload.prerelease == true {
            return .upToDate
        }
        guard let rawTagName = payload.tagName,
              let remoteVersion = SemanticVersion(string: rawTagName),
              let localVersion = SemanticVersion(string: currentVersion)
        else {
            return .failed
        }
        guard remoteVersion > localVersion else {
            return .upToDate
        }
        guard let rawHTMLURL = payload.htmlURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              let releaseURL = URL(string: rawHTMLURL),
              let scheme = releaseURL.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = releaseURL.host,
              !host.isEmpty
        else {
            return .failed
        }
        return .updateAvailable(
            version: remoteVersion.normalizedTagString,
            releaseURL: releaseURL
        )
    }

    /// Queries the GitHub Latest Release API and evaluates the response against `currentVersion`.
    public static func checkLatestRelease(
        currentVersion: String,
        session: URLSession = .shared,
        requestTimeout: TimeInterval = 15
    ) async -> CheckResult {
        var request = URLRequest(url: latestReleaseAPIURL, timeoutInterval: requestTimeout)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CueSeeker/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failed
            }
            return evaluateResponse(
                statusCode: httpResponse.statusCode,
                data: data,
                currentVersion: currentVersion
            )
        } catch {
            return .failed
        }
    }
}
