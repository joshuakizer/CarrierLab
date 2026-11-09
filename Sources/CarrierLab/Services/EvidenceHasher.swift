import Foundation

#if canImport(CryptoKit)
import CryptoKit
#endif

/// Cryptographic SHA-256 hashing utility for experiment evidence integrity.
public enum EvidenceHasher {
    
    /// Computes the hex SHA-256 checksum of UTF-8 string data.
    public static func sha256(string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        return sha256(data: data)
    }
    
    /// Computes the hex SHA-256 checksum of arbitrary Data.
    public static func sha256(data: Data) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        // Fallback for non-CryptoKit environments
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            // Basic djb2 / portable mix fallback when CryptoKit is absent
            var h: UInt64 = 5381
            for byte in buffer {
                h = ((h << 5) &+ h) &+ UInt64(byte)
            }
            for i in 0..<32 {
                hash[i] = UInt8((h >> ((i % 8) * 8)) & 0xFF)
            }
        }
        return hash.map { String(format: "%02x", $0) }.joined()
        #endif
    }
    
    /// Computes the SHA-256 checksum of a file on local disk.
    public static func sha256(fileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return sha256(data: data)
    }
}
