//
//  KeychainStorage.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import Foundation
import Security

final class KeychainStorage {
    static let shared = KeychainStorage()
    private init() {}
    // Namespace keychain items to this app for isolation
    private let serviceName: String = Bundle.main.bundleIdentifier ?? "Labby"

    func saveSecret(_ data: Data, forKey key: String) -> Bool {
        let status = saveSecretStatus(data, forKey: key)
        return status == errSecSuccess
    }

    @discardableResult
    func saveSecretStatus(_ data: Data, forKey key: String) -> OSStatus {
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemAdd(attrs as CFDictionary, nil)
        if status == errSecDuplicateItem {
            // Update existing secret
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: key,
            ]
            let updateAttrs: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            ]
            status = SecItemUpdate(query as CFDictionary, updateAttrs as CFDictionary)
        }
        return status
    }

    func loadSecretStatus(forKey key: String) -> (Data?, OSStatus) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return (data, status)
        }
        return (nil, status)
    }

    func loadSecret(forKey key: String) -> Data? {
        let (data, status) = loadSecretStatus(forKey: key)
        guard status == errSecSuccess else { return nil }
        return data
    }

    @discardableResult
    func deleteSecretStatus(forKey key: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]
        return SecItemDelete(query as CFDictionary)
    }

    func deleteSecret(forKey key: String) {
        _ = deleteSecretStatus(forKey: key)
    }
}
