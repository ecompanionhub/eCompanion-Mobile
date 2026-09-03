import Foundation

public protocol RuntimeCredentialStore: Sendable {
    func loadCredential() throws -> String?
    func saveCredential(_ credential: String) throws
    func clearCredential() throws
}

public enum RuntimeCredentialStoreError: Error, Sendable, Equatable {
    case invalidCredential
    case unexpectedStatus(Int32)
    case invalidStoredData
}

#if canImport(Security)
import Security

public struct IOSRuntimeCredentialStore: RuntimeCredentialStore, Sendable {
    private let service: String
    private let account: String

    public init(
        service: String = "app.ecompanion.body.runtime",
        account: String = "device-credential"
    ) {
        self.service = service
        self.account = account
    }

    public func loadCredential() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw RuntimeCredentialStoreError.unexpectedStatus(status)
        }
        guard
            let data = result as? Data,
            let credential = String(data: data, encoding: .utf8),
            !credential.isEmpty
        else {
            throw RuntimeCredentialStoreError.invalidStoredData
        }
        return credential
    }

    public func saveCredential(_ credential: String) throws {
        let normalized = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw RuntimeCredentialStoreError.invalidCredential }
        let data = Data(normalized.utf8)
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw RuntimeCredentialStoreError.unexpectedStatus(updateStatus)
        }

        var item = identity
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw RuntimeCredentialStoreError.unexpectedStatus(addStatus)
        }
    }

    public func clearCredential() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RuntimeCredentialStoreError.unexpectedStatus(status)
        }
    }
}
#endif

public protocol RuntimeEnrollmentProfileStore: Sendable {
    func loadProfile() throws -> RuntimeEnrollmentProfile?
    func saveProfile(_ profile: RuntimeEnrollmentProfile) throws
    func clearProfile() throws
}

public final class UserDefaultsRuntimeEnrollmentProfileStore: RuntimeEnrollmentProfileStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard, key: String = "ecompanion.runtime.enrollment") {
        self.defaults = defaults
        self.key = key
    }

    public func loadProfile() throws -> RuntimeEnrollmentProfile? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try decoder.decode(RuntimeEnrollmentProfile.self, from: data)
    }

    public func saveProfile(_ profile: RuntimeEnrollmentProfile) throws {
        defaults.set(try encoder.encode(profile), forKey: key)
    }

    public func clearProfile() throws {
        defaults.removeObject(forKey: key)
    }
}
