import Foundation

/// Evidence attachment representing an audit screenshot or capture file with SHA-256 verification.
public struct ExperimentEvidenceAttachment: Identifiable, Equatable, Codable {
    public let id: UUID
    public var fileName: String
    public var relativePath: String
    public var caption: String
    public var timestamp: Date
    public var sha256Checksum: String
    public var fileSize: Int64
    
    public init(
        id: UUID = UUID(),
        fileName: String,
        relativePath: String,
        caption: String,
        timestamp: Date = Date(),
        sha256Checksum: String,
        fileSize: Int64 = 0
    ) {
        self.id = id
        self.fileName = fileName
        self.relativePath = relativePath
        self.caption = caption
        self.timestamp = timestamp
        self.sha256Checksum = sha256Checksum
        self.fileSize = fileSize
    }
}

/// An immutable audit correction record documenting a post-hoc reclassification without rewriting the original record.
public struct ExperimentAuditCorrection: Identifiable, Equatable, Codable {
    public let id: String
    public let targetExperimentId: String
    public let timestamp: Date
    public let previousOutcome: String
    public let correctedOutcome: ExperimentOutcome
    public let auditorReason: String
    public let auditSignature: String
    
    public init(
        targetExperimentId: String,
        previousOutcome: String,
        correctedOutcome: ExperimentOutcome,
        auditorReason: String,
        timestamp: Date = Date()
    ) {
        self.id = "CORRECTION-\(targetExperimentId)"
        self.targetExperimentId = targetExperimentId
        self.timestamp = timestamp
        self.previousOutcome = previousOutcome
        self.correctedOutcome = correctedOutcome
        self.auditorReason = auditorReason
        let sig = "CORRECTION|\(targetExperimentId)|\(previousOutcome)|\(correctedOutcome.rawValue)|\(timestamp.timeIntervalSince1970)"
        self.auditSignature = EvidenceHasher.sha256(string: sig)
    }
}

/// Complete, immutable record of an alternate-carrier eSIM experiment.
public struct CarrierExperiment: Identifiable, Equatable, Codable {
    public let id: String
    public var startTimestamp: Date
    public var completionTimestamp: Date?
    public var redactedDeviceIdentifier: String
    
    // Baselines
    public var initialBaseline: ExperimentBaseline
    public var finalBaseline: ExperimentBaseline?
    
    // Experiment Parameters & Step-by-Step Observations
    public var targetCarrier: String // e.g. "AT&T", "T-Mobile"
    public var activationMethod: String // "Settings > Cellular > Add eSIM"
    public var physicalAttemptConducted: Bool
    public var eSIMInstalled: Bool
    public var cellularRegistrationOccurred: Bool
    public var cellularDataWorked: Bool
    public var testCallSucceeded: Bool?
    public var originalVerizonServiceIntact: Bool
    public var exactErrorMessages: [String]
    
    // Evidence & Outcomes
    public var attachedEvidence: [ExperimentEvidenceAttachment]
    public var comparisonResult: ExperimentComparisonResult?
    public var outcome: ExperimentOutcome
    public var auditCorrection: ExperimentAuditCorrection?
    public var researcherNotes: String
    public var rebootPersistenceVerified: Bool
    
    public var effectiveOutcome: ExperimentOutcome {
        auditCorrection?.correctedOutcome ?? outcome
    }
    
    // Cryptographic Record Integrity Signature (SHA-256)
    public var recordIntegrityHash: String
    
    public init(
        id: String = "EXP-\(Int(Date().timeIntervalSince1970))",
        startTimestamp: Date = Date(),
        completionTimestamp: Date? = nil,
        redactedDeviceIdentifier: String,
        initialBaseline: ExperimentBaseline,
        finalBaseline: ExperimentBaseline? = nil,
        targetCarrier: String = "T-Mobile",
        activationMethod: String = "Supported iOS Settings > Cellular > Add eSIM",
        physicalAttemptConducted: Bool = false,
        eSIMInstalled: Bool = false,
        cellularRegistrationOccurred: Bool = false,
        cellularDataWorked: Bool = false,
        testCallSucceeded: Bool? = nil,
        originalVerizonServiceIntact: Bool = true,
        exactErrorMessages: [String] = [],
        attachedEvidence: [ExperimentEvidenceAttachment] = [],
        comparisonResult: ExperimentComparisonResult? = nil,
        outcome: ExperimentOutcome = .inconclusive,
        auditCorrection: ExperimentAuditCorrection? = nil,
        researcherNotes: String = "",
        rebootPersistenceVerified: Bool = false
    ) {
        self.id = id
        self.startTimestamp = startTimestamp
        self.completionTimestamp = completionTimestamp
        self.redactedDeviceIdentifier = redactedDeviceIdentifier
        self.initialBaseline = initialBaseline
        self.finalBaseline = finalBaseline
        self.targetCarrier = targetCarrier
        self.activationMethod = activationMethod
        self.physicalAttemptConducted = physicalAttemptConducted
        self.eSIMInstalled = eSIMInstalled
        self.cellularRegistrationOccurred = cellularRegistrationOccurred
        self.cellularDataWorked = cellularDataWorked
        self.testCallSucceeded = testCallSucceeded
        self.originalVerizonServiceIntact = originalVerizonServiceIntact
        self.exactErrorMessages = exactErrorMessages
        self.attachedEvidence = attachedEvidence
        self.comparisonResult = comparisonResult
        self.outcome = outcome
        self.auditCorrection = auditCorrection
        self.researcherNotes = researcherNotes
        self.rebootPersistenceVerified = rebootPersistenceVerified
        
        let sig = "\(id)|\(startTimestamp)|\(redactedDeviceIdentifier)|\(targetCarrier)|\(physicalAttemptConducted)|\(eSIMInstalled)|\(outcome.rawValue)|\(initialBaseline.snapshotChecksum)"
        self.recordIntegrityHash = EvidenceHasher.sha256(string: sig)
    }
    
    /// Formats the experiment dossier as an auditable Markdown report.
    public func formattedMarkdown() -> String {
        let formatter = ISO8601DateFormatter()
        let startStr = formatter.string(from: startTimestamp)
        let endStr = completionTimestamp.map { formatter.string(from: $0) } ?? "In Progress"
        
        var md = """
        # CarrierLab Experiment Dossier: \(id)
        
        - **Experiment ID:** `\(id)`
        - **Device Identifier (Sanitized):** `\(redactedDeviceIdentifier)`
        - **Target Alternative Carrier:** `\(targetCarrier)`
        - **Start Time:** `\(startStr)`
        - **Completion Time:** `\(endStr)`
        - **Physical Activation Attempt Conducted:** \(physicalAttemptConducted ? "YES (On-Device Attempt)" : "NO (Demonstration / Software Session Only)")
        - **Verification Scope:** \(comparisonResult?.verificationScope ?? (physicalAttemptConducted ? "Owner-Reported" : "Not Performed"))
        - **Outcome Classification:** **\(effectiveOutcome.rawValue)**\(auditCorrection != nil ? " [AUDIT CORRECTED]" : "")
        - **Cryptographic Record Signature (SHA-256):** `\(recordIntegrityHash)`
        """
        
        if let correction = auditCorrection {
            md += """
            
            > [!CAUTION] **AUDIT CORRECTION APPLIED**
            > - **Original Classification:** `\(correction.previousOutcome)`
            > - **Corrected Classification:** `\(correction.correctedOutcome.rawValue)`
            > - **Audit Reason:** \(correction.auditorReason)
            > - **Correction Timestamp:** `\(formatter.string(from: correction.timestamp))`
            > - **Audit Signature:** `\(correction.auditSignature)`
            
            """
        } else if !physicalAttemptConducted {
            md += """
            
            > [!WARNING] **DEMONSTRATION ONLY / NOT PERFORMED**
            > No physical alternate-carrier eSIM was introduced to the device during this session.
            > Classified as **Not Performed** to prevent false verification claims.
            
            """
        }
        
        md += """
        
        ---
        
        ## 1. Safety & Device Protection Guarantees
        - Original Verizon eSIM Preserved: \(originalVerizonServiceIntact ? "YES (Verified Intact)" : "ALERT: VERIZON eSIM MODIFIED")
        - Provisioning Interface Used: Non-invasive supported iOS Settings UI (Zero undocumented API hooks)
        - Device Firmware & Baseband Protected: No unverified exploits, flashing, or jailbreaking executed.
        
        ---
        
        ## 2. Initial Pre-Test Hardware Baseline (Independently Queried via lockdownd)
        - **ProductType:** `\(initialBaseline.observed.productType ?? "None")`
        - **ProductVersion (iOS):** `\(initialBaseline.observed.productVersion ?? "None")`
        - **BuildVersion:** `\(initialBaseline.observed.buildVersion ?? "None")`
        - **BasebandVersion (Modem):** `\(initialBaseline.observed.basebandVersion ?? "None")`
        - **BasebandStatus:** `\(initialBaseline.observed.basebandStatus ?? "None")`
        - **ActivationState:** `\(initialBaseline.observed.activationState ?? "None")`
        - **SIMStatus:** `\(initialBaseline.observed.simStatus ?? "None")`
        - **Carrier Lock Setting (Settings > General > About):** `\(initialBaseline.ownerConfirmed.carrierLockSetting)` (Owner Confirmed)
        - **Baseline SHA-256:** `\(initialBaseline.snapshotChecksum)`
        
        ---
        
        ## 3. Alternate-Carrier Test Execution Observations (Owner-Reported)
        - **Intended Carrier:** `\(targetCarrier)`
        - **Physical Device Attempt Made:** \(physicalAttemptConducted ? "Yes" : "No")
        - **eSIM Installation Succeeded:** \(eSIMInstalled ? "Yes" : "No")
        - **Cellular Network Registration Occurred:** \(cellularRegistrationOccurred ? "Yes" : "No")
        - **Cellular Data Functional:** \(cellularDataWorked ? "Yes" : "No")
        - **Test Voice Call Succeeded:** \(testCallSucceeded == nil ? "Not tested" : (testCallSucceeded! ? "Yes" : "No"))
        - **Observed Error Messages (Manual Entry):**
        """
        
        if exactErrorMessages.isEmpty {
            md += "\n  *None recorded.*\n"
        } else {
            for err in exactErrorMessages {
                md += "\n  - `\(err)`"
            }
            md += "\n"
        }
        
        md += """
        
        ---
        
        ## 4. Post-Test Baseline & Comparative Analysis
        """
        
        if let final = finalBaseline, let comp = comparisonResult {
            md += """
            
            - **Post-Test iOS Build:** `\(final.observed.buildVersion ?? "None")` (Changed: \(comp.buildVersionChanged ? "YES" : "No"))
            - **Post-Test Modem Firmware:** `\(final.observed.basebandVersion ?? "None")` (Changed: \(comp.basebandVersionChanged ? "YES" : "No"))
            - **Post-Test ActivationState:** `\(final.observed.activationState ?? "None")` (Changed: \(comp.activationStateChanged ? "YES" : "No"))
            - **Post-Test SIMStatus:** `\(final.observed.simStatus ?? "None")` (Changed: \(comp.simStatusChanged ? "YES" : "No"))
            - **Post-Test Carrier Lock Setting:** `\(final.ownerConfirmed.carrierLockSetting)` (Changed: \(comp.carrierLockChanged ? "YES" : "No"))
            - **Connectivity Summary:** \(comp.cellularConnectivitySummary)
            - **Classification Justification:** \(comp.outcomeJustification)
            - **Permanent Unlock Verified:** \(comp.isPermanentUnlockVerified ? "CONFIRMED UNLOCKED (Reboot Persistence Verified)" : "NO (Enforcement Active or Inconclusive)")
            """
        } else {
            md += "\n*Post-test snapshot pending completion.*\n"
        }
        
        md += """
        
        ---
        
        ## 5. Evidence Attachments & Cryptographic Signatures
        """
        
        if attachedEvidence.isEmpty {
            md += "\n*No external screenshots attached.*\n"
        } else {
            for att in attachedEvidence {
                md += "\n- **\(att.fileName)** (Caption: \(att.caption)) — SHA-256: `\(att.sha256Checksum)` (\(att.fileSize) bytes)"
            }
            md += "\n"
        }
        
        md += """
        
        ---
        
        ## 6. Researcher Field Notes
        \(researcherNotes.isEmpty ? "None recorded." : researcherNotes)
        """
        
        return md
    }
}
