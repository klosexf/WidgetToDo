import Foundation
import Security

public protocol TokenStore: Sendable {
    func save(token: String) throws
    func loadToken() throws -> String?
    func deleteToken()
}

public final class KeychainTokenStore: TokenStore {
    private let service = "com.xiaofengchen.NotionFloat"
    private let account = "notion-token"

    public init() {}

    public func save(token: String) throws {
        let data = Data(token.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainTokenStoreError.unhandled(status)
        }
    }

    public func loadToken() throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainTokenStoreError.unhandled(status)
        }

        guard
            let data = item as? Data,
            let token = String(data: data, encoding: .utf8)
        else {
            throw KeychainTokenStoreError.invalidPayload
        }

        return token
    }

    public func deleteToken() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public enum KeychainTokenStoreError: Error {
    case invalidPayload
    case unhandled(OSStatus)
}
