import Foundation
import Security

struct KeychainCredentialStore: Sendable {
    let service: String

    init(service: String = AIProvider.keychainService) {
        self.service = service
    }

    func save(_ secret: String, account: String) throws {
        guard let data = secret.data(using: .utf8), !data.isEmpty else {
            throw KeychainCredentialStoreError.invalidSecret
        }

        let query = baseQuery(account: account)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            updateAttributes as CFDictionary
        )

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainCredentialStoreError.unexpectedStatus(
                    operation: "add",
                    status: addStatus
                )
            }
        default:
            throw KeychainCredentialStoreError.unexpectedStatus(
                operation: "update",
                status: updateStatus
            )
        }
    }

    func read(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let secret = String(data: data, encoding: .utf8)
            else {
                throw KeychainCredentialStoreError.invalidData
            }
            return secret
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainCredentialStoreError.unexpectedStatus(
                operation: "read",
                status: status
            )
        }
    }

    func contains(account: String) throws -> Bool {
        var query = baseQuery(account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            throw KeychainCredentialStoreError.unexpectedStatus(
                operation: "contains",
                status: status
            )
        }
    }

    func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)

        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw KeychainCredentialStoreError.unexpectedStatus(
                operation: "delete",
                status: status
            )
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum KeychainCredentialStoreError: LocalizedError {
    case invalidSecret
    case invalidData
    case unexpectedStatus(operation: String, status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidSecret:
            return "The credential is empty."
        case .invalidData:
            return "The stored credential could not be decoded."
        case .unexpectedStatus(let operation, let status):
            let message = SecCopyErrorMessageString(status, nil) as String?
            return "Keychain \(operation) failed: \(message ?? "OSStatus \(status)")"
        }
    }
}
