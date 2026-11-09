import Foundation

/// Classification of the outcome of an alternate-carrier cellular experiment.
public enum ExperimentOutcome: String, CaseIterable, Codable {
    case notPerformed = "Not Performed"
    case carrierRestrictionEnforced = "Carrier Restriction Enforced"
    case alternateCarrierActivatedLockUnchanged = "Alternative Carrier Activated (Lock Unchanged)"
    case carrierLockChangedAuthorized = "Carrier Lock Changed Following Authorized Unlock"
    case unexpectedBehavior = "Unexpected Behavior Requiring Investigation"
    case inconclusive = "Inconclusive"
    
    public var badgeColorName: String {
        switch self {
        case .notPerformed: return "gray"
        case .carrierRestrictionEnforced: return "orange" // Owner-reported, not baseband-verified
        case .alternateCarrierActivatedLockUnchanged: return "blue"
        case .carrierLockChangedAuthorized: return "purple"
        case .unexpectedBehavior: return "red"
        case .inconclusive: return "gray"
        }
    }
    
    public var description: String {
        switch self {
        case .notPerformed:
            return "No physical alternate-carrier activation was attempted on the device. Experiment conducted entirely in software or demonstration mode."
        case .carrierRestrictionEnforced:
            return "Owner reported alternative carrier eSIM was rejected under active Verizon lock. (Owner-reported observation; not independently verified by baseband)."
        case .alternateCarrierActivatedLockUnchanged:
            return "Alternative carrier registered or provided cellular data while Settings still reports SIM locked (e.g. dual active profile or international roaming agreement)."
        case .carrierLockChangedAuthorized:
            return "Carrier Lock transitioned to 'No SIM Restrictions' through legitimate carrier GSX fulfillment and Apple-signed unlock ticket."
        case .unexpectedBehavior:
            return "Inconsistency or safety violation observed (e.g., primary Verizon eSIM compromised or unexpected baseband state)."
        case .inconclusive:
            return "Test could not be completed, device was disconnected, or insufficient supporting evidence was provided."
        }
    }
}

/// Comparison analysis between an initial and post-test baseline snapshot.
public struct ExperimentComparisonResult: Equatable, Codable {
    public var activationStateChanged: Bool
    public var initialActivationState: String?
    public var finalActivationState: String?
    
    public var simStatusChanged: Bool
    public var initialSIMStatus: String?
    public var finalSIMStatus: String?
    
    public var basebandVersionChanged: Bool
    public var initialBasebandVersion: String?
    public var finalBasebandVersion: String?
    
    public var buildVersionChanged: Bool
    public var initialBuildVersion: String?
    public var finalBuildVersion: String?
    
    public var carrierLockChanged: Bool
    public var initialCarrierLock: String
    public var finalCarrierLock: String
    
    public var cellularConnectivitySummary: String
    public var classifiedOutcome: ExperimentOutcome
    public var outcomeJustification: String
    
    /// Strict unlock verification gate:
    /// Requires ALL of the following:
    /// 1. Final Carrier Lock setting verified as 'No SIM Restrictions'
    /// 2. Alternate carrier successfully registered and passed data test
    /// 3. Persistence manually verified after physical device restart
    public var originalVerizonServiceIntact: Bool
    public var physicalAttemptConducted: Bool
    public var hasSupportingEvidence: Bool
    public var verificationScope: String
    public var isPermanentUnlockVerified: Bool
    public var rebootPersistenceConfirmed: Bool
    
    public init(
        initial: ExperimentBaseline,
        final: ExperimentBaseline,
        eSIMInstalled: Bool,
        cellularDataWorked: Bool,
        originalVerizonServiceIntact: Bool = true,
        physicalAttemptConducted: Bool = false,
        hasSupportingEvidence: Bool = false,
        rebootPersistenceConfirmed: Bool = false,
        technicianNotes: String = ""
    ) {
        self.initialActivationState = initial.observed.activationState
        self.finalActivationState = final.observed.activationState
        self.activationStateChanged = (initial.observed.activationState != final.observed.activationState)
        
        self.initialSIMStatus = initial.observed.simStatus
        self.finalSIMStatus = final.observed.simStatus
        self.simStatusChanged = (initial.observed.simStatus != final.observed.simStatus)
        
        self.initialBasebandVersion = initial.observed.basebandVersion
        self.finalBasebandVersion = final.observed.basebandVersion
        self.basebandVersionChanged = (initial.observed.basebandVersion != final.observed.basebandVersion)
        
        self.initialBuildVersion = initial.observed.buildVersion
        self.finalBuildVersion = final.observed.buildVersion
        self.buildVersionChanged = (initial.observed.buildVersion != final.observed.buildVersion)
        
        self.initialCarrierLock = initial.ownerConfirmed.carrierLockSetting
        self.finalCarrierLock = final.ownerConfirmed.carrierLockSetting
        self.carrierLockChanged = (initial.ownerConfirmed.carrierLockSetting != final.ownerConfirmed.carrierLockSetting)
        
        self.originalVerizonServiceIntact = originalVerizonServiceIntact
        self.physicalAttemptConducted = physicalAttemptConducted
        self.hasSupportingEvidence = hasSupportingEvidence
        self.rebootPersistenceConfirmed = rebootPersistenceConfirmed
        
        // Connectivity summary
        var connectivity = originalVerizonServiceIntact ? "Original Verizon service: Active. " : "CRITICAL ALERT: Original Verizon service is compromised or inactive! "
        if !physicalAttemptConducted {
            connectivity += "Alternative carrier test: Not Performed (Software Session Only)."
        } else if cellularDataWorked {
            connectivity += "Alternative carrier data: Active. "
        } else {
            connectivity += "Alternative carrier data: Inactive/Rejected. "
        }
        self.cellularConnectivitySummary = connectivity
        
        // Automated outcome classification engine
        if !originalVerizonServiceIntact {
            self.classifiedOutcome = .unexpectedBehavior
            self.outcomeJustification = "CRITICAL SAFETY VIOLATION: Primary Verizon eSIM was modified, removed, or deactivated. Test invalidated."
            self.isPermanentUnlockVerified = false
            self.verificationScope = "Safety Alert (Verizon eSIM Compromised)"
        } else if !physicalAttemptConducted {
            self.classifiedOutcome = .notPerformed
            self.outcomeJustification = "No physical alternate-carrier activation attempt was conducted on the physical device. Experiment conducted entirely within software. Classified as Not Performed."
            self.isPermanentUnlockVerified = false
            self.verificationScope = "Not Performed (Software Session Only)"
        } else if finalCarrierLock.localizedCaseInsensitiveContains("No SIM") && rebootPersistenceConfirmed && cellularDataWorked {
            self.classifiedOutcome = .carrierLockChangedAuthorized
            self.outcomeJustification = "Carrier Lock officially transitioned to 'No SIM Restrictions' and persisted after device reboot."
            self.isPermanentUnlockVerified = true
            self.verificationScope = "Authorized Unlock Confirmed (Reboot Verified)"
        } else if !hasSupportingEvidence && !eSIMInstalled && !cellularDataWorked {
            self.classifiedOutcome = .inconclusive
            self.outcomeJustification = "Physical activation attempt was reported, but no corroborating error strings, screenshots, or modem state changes were recorded to substantiate carrier restriction."
            self.isPermanentUnlockVerified = false
            self.verificationScope = "Inconclusive (Missing Supporting Evidence)"
        } else if (!eSIMInstalled || !cellularDataWorked) && finalCarrierLock.localizedCaseInsensitiveContains("Locked") {
            self.classifiedOutcome = .carrierRestrictionEnforced
            self.outcomeJustification = "Owner reported alternative carrier was rejected under active Verizon lock. (Note: Owner-reported observation; not independently verified by baseband telemetry)."
            self.isPermanentUnlockVerified = false
            self.verificationScope = "Owner-Reported Observation (Unverified by Baseband)"
        } else if cellularDataWorked && finalCarrierLock.localizedCaseInsensitiveContains("Locked") {
            self.classifiedOutcome = .alternateCarrierActivatedLockUnchanged
            self.outcomeJustification = "Alternative carrier connected while Settings displays SIM Locked. Warning: Does not constitute an unlock; requires verification of carrier bundle roaming."
            self.isPermanentUnlockVerified = false
            self.verificationScope = "Owner-Reported (Lock Inconsistency)"
        } else if !technicianNotes.isEmpty && technicianNotes.localizedCaseInsensitiveContains("anomaly") {
            self.classifiedOutcome = .unexpectedBehavior
            self.outcomeJustification = "Baseband or CommCenter exhibited unexpected behavior requiring deep IPC trace."
            self.isPermanentUnlockVerified = false
            self.verificationScope = "Telemetry Anomaly Investigation"
        } else {
            self.classifiedOutcome = .inconclusive
            self.outcomeJustification = "Observations insufficient for definitive classification."
            self.isPermanentUnlockVerified = false
            self.verificationScope = "Inconclusive"
        }
    }
}
