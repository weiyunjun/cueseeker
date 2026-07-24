import CryptoKit
import Foundation

public enum ResourceBindingState: String, Equatable, Sendable {
    case available
    case missing
    case removed
    case replaced
    case conflict
}

public struct FileResourceIdentity: Equatable, Sendable {
    public let resourceIdentifier: String?
    public let contentFingerprint: String?

    public init(resourceIdentifier: String?, contentFingerprint: String?) {
        self.resourceIdentifier = resourceIdentifier
        self.contentFingerprint = contentFingerprint
    }
}

public enum FileResourceIdentityResolver {
    public static func resolve(
        _ file: URL,
        includesContentFingerprint: Bool
    ) -> FileResourceIdentity {
        FileResourceIdentity(
            resourceIdentifier: resourceIdentifier(for: file),
            contentFingerprint: includesContentFingerprint ? contentFingerprint(for: file) : nil
        )
    }

    public static func resourceIdentifier(for file: URL) -> String? {
        let keys: Set<URLResourceKey> = [
            .fileResourceIdentifierKey,
            .volumeIdentifierKey,
            .creationDateKey
        ]
        guard let values = try? file.standardizedFileURL.resourceValues(forKeys: keys),
              let fileIdentifier = archivedIdentifier(values.fileResourceIdentifier)
        else {
            return nil
        }

        let volumeIdentifier = archivedIdentifier(values.volumeIdentifier) ?? ""
        let creationTimestamp = values.creationDate?.timeIntervalSinceReferenceDate.bitPattern ?? 0
        return [volumeIdentifier, fileIdentifier, String(creationTimestamp)]
            .joined(separator: ":")
    }

    public static func contentFingerprint(for file: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: file) else {
            return nil
        }
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        do {
            while true {
                let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
                guard !data.isEmpty else {
                    break
                }
                hasher.update(data: data)
            }
        } catch {
            return nil
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func archivedIdentifier(_ value: Any?) -> String? {
        guard let value,
              let data = try? NSKeyedArchiver.archivedData(
                  withRootObject: value,
                  requiringSecureCoding: true
              )
        else {
            return nil
        }
        return data.base64EncodedString()
    }
}
