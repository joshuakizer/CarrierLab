import Foundation

/// Utility to sanitize and redact sensitive hardware identifiers.
/// Enforces rule: Never expose full device identifiers in shared logs or reports.
public enum DeviceSanitizer {
    
    /// Redacts a UDID / UniqueDeviceID, keeping only the last 4 characters.
    /// Example: "00008110-0001234567890ABC" -> "••••••••••••••••••••••••••••••••••••0ABC"
    public static func sanitizeUDID(_ udid: String?) -> String? {
        guard let raw = udid, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 4 {
            return "••••"
        }
        let suffix = trimmed.suffix(4)
        let mask = String(repeating: "•", count: trimmed.count - 4)
        return mask + suffix
    }
    
    /// Redacts an IMEI or MEID, preserving only the last 4 digits.
    /// Example: "353014101234567" -> "•••••••••••4567"
    public static func sanitizeIMEI(_ imei: String?) -> String? {
        guard let raw = imei, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 4 {
            return "••••"
        }
        let suffix = trimmed.suffix(4)
        let mask = String(repeating: "•", count: trimmed.count - 4)
        return mask + suffix
    }
    
    /// Redacts a hardware serial number, preserving only the last 3 characters.
    /// Example: "F2LZX123GHK9" -> "•••••••••HK9"
    public static func sanitizeSerialNumber(_ serial: String?) -> String? {
        guard let raw = serial, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 3 {
            return "•••"
        }
        let suffix = trimmed.suffix(3)
        let mask = String(repeating: "•", count: trimmed.count - 3)
        return mask + suffix
    }
    
    /// Redacts common identifiers found in raw log strings using regular expressions.
    public static func sanitizeLogMessage(_ message: String) -> String {
        var sanitized = message
        
        // Match 40-char hex UDID
        if let udidRegex = try? NSRegularExpression(pattern: "\\b[a-fA-F0-9]{40}\\b", options: []) {
            let range = NSRange(location: 0, length: sanitized.utf16.count)
            let matches = udidRegex.matches(in: sanitized, options: [], range: range).reversed()
            for match in matches {
                if let swiftRange = Range(match.range, in: sanitized) {
                    let full = String(sanitized[swiftRange])
                    let masked = "••••••••••••••••••••••••••••••••••••" + full.suffix(4)
                    sanitized.replaceSubrange(swiftRange, with: masked)
                }
            }
        }
        
        // Match 25-char hyphenated Apple Silicon UDID (e.g., 00008110-001234567890ABCD)
        if let newUdidRegex = try? NSRegularExpression(pattern: "\\b0000[0-9]{4}-[0-9a-fA-F]{16}\\b", options: []) {
            let range = NSRange(location: 0, length: sanitized.utf16.count)
            let matches = newUdidRegex.matches(in: sanitized, options: [], range: range).reversed()
            for match in matches {
                if let swiftRange = Range(match.range, in: sanitized) {
                    let full = String(sanitized[swiftRange])
                    let masked = "••••••••••••••••••••" + full.suffix(4)
                    sanitized.replaceSubrange(swiftRange, with: masked)
                }
            }
        }
        
        // Match 15-digit IMEI
        if let imeiRegex = try? NSRegularExpression(pattern: "\\b[0-9]{15}\\b", options: []) {
            let range = NSRange(location: 0, length: sanitized.utf16.count)
            let matches = imeiRegex.matches(in: sanitized, options: [], range: range).reversed()
            for match in matches {
                if let swiftRange = Range(match.range, in: sanitized) {
                    let full = String(sanitized[swiftRange])
                    let masked = "•••••••••••" + full.suffix(4)
                    sanitized.replaceSubrange(swiftRange, with: masked)
                }
            }
        }
        
        return sanitized
    }
}
