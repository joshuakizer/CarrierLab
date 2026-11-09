import Foundation

/// Represents an immutable hardware and cellular baseline snapshot.
/// Strictly separates:
/// 1. Device-observed telemetry (read directly from lockdownd/usbmuxd)
/// 2. Owner-confirmed observations (manually verified in physical device Settings)
/// 3. Technical interpretations (cryptographic and protocol explanations)
public struct ExperimentBaseline: Identifiable, Equatable, Codable {
    
    public struct DeviceObserved: Equatable, Codable {
        public var productType: String?
        public var productVersion: String?
        public var buildVersion: String?
        public var basebandVersion: String?
        public var basebandStatus: String?
        public var activationState: String?
        public var simStatus: String?
        public var sanitizedUDID: String?
        public var rawProperties: [String: String]
        
        public init(
            productType: String? = nil,
            productVersion: String? = nil,
            buildVersion: String? = nil,
            basebandVersion: String? = nil,
            basebandStatus: String? = nil,
            activationState: String? = nil,
            simStatus: String? = nil,
            sanitizedUDID: String? = nil,
            rawProperties: [String: String] = [:]
        ) {
            self.productType = productType
            self.productVersion = productVersion
            self.buildVersion = buildVersion
            self.basebandVersion = basebandVersion
            self.basebandStatus = basebandStatus
            self.activationState = activationState
            self.simStatus = simStatus
            self.sanitizedUDID = sanitizedUDID
            self.rawProperties = rawProperties
        }
    }
    
    public struct OwnerConfirmed: Equatable, Codable {
        public var carrierLockSetting: String  // e.g. "SIM Locked" or "No SIM Restrictions"
        public var activeCarrier: String       // e.g. "Verizon"
        public var financingStatus: String      // e.g. "Active installment plan"
        public var settingsPath: String         // "Settings > General > About > Carrier Lock"
        public var technicianID: String
        public var manualNotes: String
        
        public init(
            carrierLockSetting: String = "SIM Locked",
            activeCarrier: String = "Verizon",
            financingStatus: String = "Active Installment Plan / Financed",
            settingsPath: String = "Settings > General > About > Carrier Lock",
            technicianID: String = "Lead-Researcher",
            manualNotes: String = "Physically confirmed in Settings > General > About on device."
        ) {
            self.carrierLockSetting = carrierLockSetting
            self.activeCarrier = activeCarrier
            self.financingStatus = financingStatus
            self.settingsPath = settingsPath
            self.technicianID = technicianID
            self.manualNotes = manualNotes
        }
    }
    
    public struct TechnicalInterpretation: Equatable, Codable {
        public var simStatusAnalysis: String
        public var lockEnforcementSummary: String
        
        public init(
            simStatusAnalysis: String = "kCTSIMSupportSIMStatusReady indicates that the installed Verizon SIM/eSIM application is accepted and authenticated by CommCenter. It does NOT denote that the phone is carrier-unlocked.",
            lockEnforcementSummary: String = "Carrier lock enforcement is mediated by Apple's signed WildcardTicket. In-market SIM lock prevents non-Verizon network registration regardless of USIM readiness."
        ) {
            self.simStatusAnalysis = simStatusAnalysis
            self.lockEnforcementSummary = lockEnforcementSummary
        }
    }
    
    public let id: UUID
    public let label: String
    public let timestamp: Date
    public let observed: DeviceObserved
    public let ownerConfirmed: OwnerConfirmed
    public let interpretation: TechnicalInterpretation
    public let snapshotChecksum: String
    
    public init(
        id: UUID = UUID(),
        label: String = "Initial Baseline",
        timestamp: Date = Date(),
        observed: DeviceObserved,
        ownerConfirmed: OwnerConfirmed,
        interpretation: TechnicalInterpretation = TechnicalInterpretation()
    ) {
        self.id = id
        self.label = label
        self.timestamp = timestamp
        self.observed = observed
        self.ownerConfirmed = ownerConfirmed
        self.interpretation = interpretation
        
        // Compute immutable integrity checksum over the captured telemetry
        let signature = "\(label)|\(timestamp.timeIntervalSince1970)|\(observed.productType ?? "")|\(observed.productVersion ?? "")|\(observed.buildVersion ?? "")|\(observed.basebandVersion ?? "")|\(observed.simStatus ?? "")|\(ownerConfirmed.carrierLockSetting)"
        self.snapshotChecksum = EvidenceHasher.sha256(string: signature)
    }
    
    /// Convenience initializer from live DeviceDiagnostics
    public static func fromDiagnostics(
        _ diag: DeviceDiagnostics?,
        label: String = "Initial Baseline",
        ownerLockSetting: String = "SIM Locked",
        carrier: String = "Verizon",
        technician: String = "Lead-Researcher",
        notes: String = ""
    ) -> ExperimentBaseline {
        let obs = DeviceObserved(
            productType: diag?.productType,
            productVersion: diag?.productVersion,
            buildVersion: diag?.buildVersion,
            basebandVersion: diag?.basebandVersion,
            basebandStatus: diag?.basebandStatus,
            activationState: diag?.activationState,
            simStatus: diag?.simStatus,
            sanitizedUDID: diag?.sanitizedUDID,
            rawProperties: diag?.rawProperties ?? [:]
        )
        let confirmed = OwnerConfirmed(
            carrierLockSetting: ownerLockSetting,
            activeCarrier: carrier,
            financingStatus: "Active Installment Plan / Financed",
            technicianID: technician,
            manualNotes: notes
        )
        return ExperimentBaseline(
            label: label,
            observed: obs,
            ownerConfirmed: confirmed
        )
    }
}
