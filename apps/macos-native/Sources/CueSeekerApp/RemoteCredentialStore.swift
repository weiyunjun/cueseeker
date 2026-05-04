import Foundation
import Security
import CueSeekerCore

enum RemoteCredentialStoreError: Error, CustomStringConvertible {
    case encodeFailed
    case decodeFailed
    case keychainStatus(OSStatus)

    var description: String {
        switch self {
        case .encodeFailed:
            "Remote source credentials could not be encoded."
        case .decodeFailed:
            "Remote source credentials could not be decoded."
        case .keychainStatus(let status):
            "Keychain operation failed with status \(status)."
        }
    }
}

struct RemoteCredentialStore: Sendable {
    private static let service = "CueSeeker.RemoteSourceCredentials"

    func save(_ credentials: RemoteMediaSourceCredentials, credentialRef: String) throws {
        guard let data = try? JSONEncoder().encode(credentials) else {
            throw RemoteCredentialStoreError.encodeFailed
        }

        let query = baseQuery(credentialRef: credentialRef)
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw RemoteCredentialStoreError.keychainStatus(status)
        }
    }

    func load(credentialRef: String?) throws -> RemoteMediaSourceCredentials {
        guard let credentialRef, !credentialRef.isEmpty else {
            return RemoteMediaSourceCredentials(username: "", password: "")
        }

        var query = baseQuery(credentialRef: credentialRef)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            throw RemoteCredentialStoreError.keychainStatus(status)
        }
        guard let data = item as? Data,
              let credentials = try? JSONDecoder().decode(RemoteMediaSourceCredentials.self, from: data)
        else {
            throw RemoteCredentialStoreError.decodeFailed
        }
        return credentials
    }

    func delete(credentialRef: String?) {
        guard let credentialRef, !credentialRef.isEmpty else {
            return
        }
        SecItemDelete(baseQuery(credentialRef: credentialRef) as CFDictionary)
    }

    private func baseQuery(credentialRef: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: credentialRef
        ]
    }
}
