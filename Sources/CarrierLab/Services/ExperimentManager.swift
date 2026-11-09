import Foundation

/// Manages local storage, cryptographic validation, and retrieval of Carrier Experiments.
public final class ExperimentManager {
    
    public static let shared = ExperimentManager()
    
    public let baseDirectory: URL
    
    public init(customBaseDirectory: URL? = nil) {
        if let custom = customBaseDirectory {
            self.baseDirectory = custom
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.baseDirectory = home.appendingPathComponent("CarrierLabExperiments", isDirectory: true)
        }
        createDirectoriesIfNeeded()
    }
    
    private func createDirectoriesIfNeeded() {
        let fm = FileManager.default
        let attachmentsDir = baseDirectory.appendingPathComponent("attachments", isDirectory: true)
        let reportsDir = baseDirectory.appendingPathComponent("dossiers", isDirectory: true)
        
        try? fm.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try? fm.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: reportsDir, withIntermediateDirectories: true)
    }
    
    /// Saves a new experiment. Fails if an experiment with the same ID already exists to prevent silent overwriting.
    @discardableResult
    public func saveExperiment(_ experiment: CarrierExperiment, allowOverwrite: Bool = false) throws -> (jsonURL: URL, markdownURL: URL) {
        createDirectoriesIfNeeded()
        let fm = FileManager.default
        
        let jsonURL = baseDirectory.appendingPathComponent("\(experiment.id).json")
        let mdURL = baseDirectory.appendingPathComponent("dossiers/\(experiment.id).md")
        
        if !allowOverwrite && fm.fileExists(atPath: jsonURL.path) {
            throw NSError(
                domain: "CarrierLab.ExperimentManager",
                code: 409,
                userInfo: [NSLocalizedDescriptionKey: "Experiment '\(experiment.id)' already exists. Silent overwrites are blocked to protect audit integrity."]
            )
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(experiment)
        try data.write(to: jsonURL, options: .atomic)
        
        let mdContent = experiment.formattedMarkdown()
        guard let mdData = mdContent.data(using: .utf8) else {
            throw NSError(domain: "CarrierLab.ExperimentManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Encoding failure for markdown dossier."])
        }
        try mdData.write(to: mdURL, options: .atomic)
        
        return (jsonURL, mdURL)
    }
    
    /// Saves an auditable correction record without altering the original experiment JSON.
    @discardableResult
    public func saveAuditCorrection(_ correction: ExperimentAuditCorrection) throws -> (jsonURL: URL, markdownURL: URL) {
        createDirectoriesIfNeeded()
        let jsonURL = baseDirectory.appendingPathComponent("\(correction.id).json")
        let mdURL = baseDirectory.appendingPathComponent("dossiers/\(correction.id).md")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(correction)
        try data.write(to: jsonURL, options: .atomic)
        
        let formatter = ISO8601DateFormatter()
        let timeStr = formatter.string(from: correction.timestamp)
        let mdContent = """
        # CarrierLab Audit Correction Dossier: \(correction.id)
        
        - **Correction ID:** `\(correction.id)`
        - **Target Experiment ID:** `\(correction.targetExperimentId)`
        - **Timestamp:** `\(timeStr)`
        - **Original Recorded Outcome:** `\(correction.previousOutcome)`
        - **Corrected Outcome:** **\(correction.correctedOutcome.rawValue)**
        - **Audit Reason:** \(correction.auditorReason)
        - **Cryptographic Audit Signature:** `\(correction.auditSignature)`
        
        ---
        
        ## Audit Certification
        This correction was generated to amend an unverified or software-only test record without altering or deleting the original historical telemetry file.
        """
        if let mdData = mdContent.data(using: .utf8) {
            try? mdData.write(to: mdURL, options: .atomic)
        }
        return (jsonURL, mdURL)
    }
    
    /// Retrieves any existing audit correction for a specific experiment ID.
    public func loadCorrection(for experimentId: String) -> ExperimentAuditCorrection? {
        let correctionURL = baseDirectory.appendingPathComponent("CORRECTION-\(experimentId).json")
        guard let data = try? Data(contentsOf: correctionURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ExperimentAuditCorrection.self, from: data)
    }
    
    /// Ensures that known erroneous/software-only test records such as EXP-1794188993 have an auditable correction entry.
    public func ensureAuditCorrectionForEXP1794188993() {
        let targetId = "EXP-1794188993"
        let correctionFile = baseDirectory.appendingPathComponent("CORRECTION-\(targetId).json")
        if !FileManager.default.fileExists(atPath: correctionFile.path) {
            let correction = ExperimentAuditCorrection(
                targetExperimentId: targetId,
                previousOutcome: "Carrier Restriction Enforced",
                correctedOutcome: .notPerformed,
                auditorReason: "Audit established that this experiment was executed entirely within the CarrierLab software without a physical alternate-carrier activation attempt on the physical Verizon iPhone Duo. Reclassified as Not Performed in accordance with CarrierLab Research Audit Policy."
            )
            try? saveAuditCorrection(correction)
        }
    }
    
    /// Loads all saved experiments from disk sorted by start timestamp (newest first).
    public func loadAllExperiments() -> [CarrierExperiment] {
        createDirectoriesIfNeeded()
        ensureAuditCorrectionForEXP1794188993()
        
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var experiments: [CarrierExperiment] = []
        for file in files where file.pathExtension == "json" && !file.lastPathComponent.hasPrefix("CORRECTION-") {
            if let data = try? Data(contentsOf: file),
               var exp = try? decoder.decode(CarrierExperiment.self, from: data) {
                if let correction = loadCorrection(for: exp.id) {
                    exp.auditCorrection = correction
                }
                experiments.append(exp)
            }
        }
        
        return experiments.sorted { $0.startTimestamp > $1.startTimestamp }
    }
    
    /// Copies an image file into the experiment attachments directory and returns an EvidenceAttachment record with SHA-256.
    public func attachScreenshot(
        experimentId: String,
        sourceURL: URL,
        caption: String
    ) throws -> ExperimentEvidenceAttachment {
        createDirectoriesIfNeeded()
        let fm = FileManager.default
        let expAttachDir = baseDirectory.appendingPathComponent("attachments/\(experimentId)", isDirectory: true)
        try fm.createDirectory(at: expAttachDir, withIntermediateDirectories: true)
        
        let targetFileName = "\(UUID().uuidString)_\(sourceURL.lastPathComponent)"
        let targetURL = expAttachDir.appendingPathComponent(targetFileName)
        
        if fm.fileExists(atPath: targetURL.path) {
            try? fm.removeItem(at: targetURL)
        }
        try fm.copyItem(at: sourceURL, to: targetURL)
        
        guard let checksum = EvidenceHasher.sha256(fileURL: targetURL) else {
            throw NSError(domain: "CarrierLab.ExperimentManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to compute SHA-256 for attachment."])
        }
        
        let attributes = try? fm.attributesOfItem(atPath: targetURL.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        
        return ExperimentEvidenceAttachment(
            fileName: sourceURL.lastPathComponent,
            relativePath: "attachments/\(experimentId)/\(targetFileName)",
            caption: caption,
            timestamp: Date(),
            sha256Checksum: checksum,
            fileSize: fileSize
        )
    }
    
    /// Validates that an experiment's recorded integrity hash matches its content.
    public func verifyIntegrity(of experiment: CarrierExperiment) -> Bool {
        let expectedSig = "\(experiment.id)|\(experiment.startTimestamp)|\(experiment.redactedDeviceIdentifier)|\(experiment.targetCarrier)|\(experiment.physicalAttemptConducted)|\(experiment.eSIMInstalled)|\(experiment.outcome.rawValue)|\(experiment.initialBaseline.snapshotChecksum)"
        let computed = EvidenceHasher.sha256(string: expectedSig)
        return computed == experiment.recordIntegrityHash
    }
}
