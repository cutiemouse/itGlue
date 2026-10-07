import Foundation
import Security
import CommonCrypto

enum PINError: LocalizedError {
    case invalidFormat, keychain(OSStatus), derivation, locked(Date), incorrect
    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Use a PIN containing 6–12 digits."
        case .keychain(let status): return "Keychain could not be accessed (\(status)). Settings remain locked."
        case .derivation: return "The PIN could not be secured."
        case .locked(let date): return "Try again after \(date.formatted(date: .omitted, time: .shortened))."
        case .incorrect: return "Incorrect parent PIN."
        }
    }
}

/// No raw PIN is persisted. A random salt and PBKDF2-HMAC-SHA256 verifier live in Keychain.
final class ParentPINService {
    private struct Record: Codable {
        var salt: Data
        var digest: Data
        var failedAttempts = 0
        var retryAfter: Date? = nil
    }
    private let service = "com.studyguardian.parent-pin"
    private let account = "parent"

    func exists() throws -> Bool { try read() != nil }
    func create(_ pin: String) throws {
        guard try read() == nil else { throw PINError.incorrect }
        guard (6...12).contains(pin.count), pin.allSatisfy({ $0.isASCII && $0.isNumber }) else { throw PINError.invalidFormat }
        var salt = Data(count: 32)
        let result = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        guard result == errSecSuccess else { throw PINError.keychain(result) }
        try write(Record(salt: salt, digest: try derive(pin, salt: salt)))
    }
    func verify(_ pin: String) throws {
        guard var record = try read() else { throw PINError.incorrect }
        if let retry = record.retryAfter, retry > Date() { throw PINError.locked(retry) }
        let candidate = try derive(pin, salt: record.salt)
        let difference = zip(candidate, record.digest).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) }
        if candidate.count != record.digest.count || difference != 0 {
            record.failedAttempts += 1
            if record.failedAttempts >= 5 {
                let seconds = min(3600.0, 30.0 * pow(2.0, Double(min(7, record.failedAttempts - 5))))
                record.retryAfter = Date().addingTimeInterval(seconds)
            }
            try write(record)
            throw PINError.incorrect
        }
        record.failedAttempts = 0
        record.retryAfter = nil
        try write(record)
    }
    private func derive(_ pin: String, salt: Data) throws -> Data {
        var result = Data(count: 32)
        let status = pin.utf8CString.withUnsafeBufferPointer { password in
            salt.withUnsafeBytes { saltBytes in
                result.withUnsafeMutableBytes { output in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), password.baseAddress!, pin.utf8.count,
                                        saltBytes.bindMemory(to: UInt8.self).baseAddress!, salt.count,
                                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 210_000,
                                        output.bindMemory(to: UInt8.self).baseAddress!, 32)
                }
            }
        }
        guard status == kCCSuccess else { throw PINError.derivation }
        return result
    }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
    private func read() throws -> Record? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw PINError.keychain(status) }
        return try JSONDecoder().decode(Record.self, from: data)
    }
    private func write(_ record: Record) throws {
        let data = try JSONEncoder().encode(record)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var request = query
            request[kSecValueData as String] = data
            request[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let added = SecItemAdd(request as CFDictionary, nil)
            guard added == errSecSuccess else { throw PINError.keychain(added) }
        } else if status != errSecSuccess { throw PINError.keychain(status) }
    }
}
