// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Security

// Minimal Keychain wrapper. One generic-password item per (service, account).
// We use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` so credentials
// are decryptable after first unlock (background refresh works) but never
// leave the device.
public enum Keychain {

    public enum Failure: Error, LocalizedError {
        case osStatus(OSStatus)
        case encoding
        public var errorDescription: String? {
            switch self {
            case .osStatus(let s): return "Keychain error (status \(s))."
            case .encoding:        return "Couldn't encode credential as UTF-8."
            }
        }
    }

    public static func set(_ value: String, service: String, account: String) throws {
        guard let data = value.data(using: .utf8) else { throw Failure.encoding }
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw Failure.osStatus(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw Failure.osStatus(updateStatus)
        }
    }

    public static func get(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw Failure.osStatus(status) }
        guard let data = result as? Data,
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    public static func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure.osStatus(status)
        }
    }
}
