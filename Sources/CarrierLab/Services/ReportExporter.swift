import Foundation

/// Handles saving timestamped diagnostic reports to local disk.
public enum ReportExporter {
    
    public static func defaultReportsDirectory() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent("CarrierLabReports", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    /// Exports report as both JSON and Markdown with timestamped filename.
    public static func exportReport(
        _ report: DiagnosticReport,
        targetDirectory: URL? = nil
    ) throws -> (jsonURL: URL, markdownURL: URL) {
        let dir = targetDirectory ?? defaultReportsDirectory()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestampStr = formatter.string(from: report.timestamp)
        
        let jsonURL = dir.appendingPathComponent("CarrierLab_Diagnostic_\(timestampStr).json")
        let mdURL = dir.appendingPathComponent("CarrierLab_Diagnostic_\(timestampStr).md")
        
        // Encode JSON with pretty printing and sorted keys
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(report)
        try jsonData.write(to: jsonURL, options: .atomic)
        
        // Write Markdown
        let mdContent = report.formattedMarkdown()
        guard let mdData = mdContent.data(using: .utf8) else {
            throw NSError(domain: "CarrierLab", code: -1, userInfo: [NSLocalizedDescriptionKey: "UTF-8 encoding failure"])
        }
        try mdData.write(to: mdURL, options: .atomic)
        
        return (jsonURL, mdURL)
    }
}
