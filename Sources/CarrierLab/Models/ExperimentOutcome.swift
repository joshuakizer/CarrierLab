import Foundation

/// Classification of the outcome of an alternate-carrier cellular experiment.
public enum ExperimentOutcome: String, CaseIterable, Codable {
    case carrierRestrictionEnforced = "Carrier Restriction Enforced"
    case alternateCarrierActivatedLockUnchanged = "Alternative Carrier Activated (Lock Unchanged)"
    case carrierLockChangedAuthorized = "Carrier Lock Changed Following Authorized Unlock"
    case unexpectedBehavior = "Unexpected Behavior Requiring Investigation"
    case inconclusive = "Inconclusive"
    
    public var badgeColorName: String {
        switch self {
        case .carrierRestrictionEnforced: return "green" // Expected, normal behavior
        case .alternateCarrierActivatedLockUnchanged: return "blue"
        case .carrierLockChangedAuthorized: return "purple"
        case .unexpectedBehavior: return "orange"
        case .inconclusive: return "gray"
        }
    }
    
    public var description: String {
        switch self {
        case .carrierRestrictionEnforced:
            return "Expected enforcement: Alternative carrier eSIM was rejected by iOS activation policy or baseband; original Verizon service remained intact."
        case .alternateCarrierActivatedLockUnchanged:
            return "Alternative carrier registered or provided cellular data while Settings still reports SIM locked (e.g. dual active profile or international roaming agreement)."
        case .carrierLockChangedAuthorized:
            return "Carrier Lock transitioned to 'No SIM Restrictions' through legitimate carrier GSX fulfillment and Apple-signed unlock ticket."
        case .unexpectedBehavior:
            return "Inconsistency observed between reported lock status and baseband registration that cannot be explained by standard activation policies."
        case .inconclusive:
            return "Test could not be completed, device was disconnected, or user aborted the activation attempt."
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
    public var isPermanentUnlockVerified: Bool
    public var rebootPersistenceConfirmed: Bool
    
    public init(
        initial: ExperimentBaseline,
        final: ExperimentBaseline,
        eSIMInstalled: Bool,
        cellularDataWorked: Bool,
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
        
        self.rebootPersistenceConfirmed = rebootPersistenceConfirmed
        
        // Connectivity summary
        var connectivity = "Original Verizon service: Active. "
        if cellularDataWorked {
            connectivity += "Alternative carrier data: Active. "
        } else {
            connectivity += "Alternative carrier data: Inactive/Rejected. "
        }
        self.cellularConnectivitySummary = connectivity
        
        // Automated outcome classification engine
        if finalCarrierLock.localizedCaseInsensitiveContains("No SIM") && rebootPersistenceConfirmed {
            self.classifiedOutcome = .carrierLockChangedAuthorized
            self.outcomeJustification = "Carrier Lock officially transitioned to 'No SIM Restrictions' and persisted after device reboot."
            self.isPermanentUnlockVerified = true
        } else if !eSIMInstalled || (!cellularDataWorked && finalCarrierLock.localizedCaseInsensitiveContains("Locked")) {
            self.classifiedOutcome = .carrierRestrictionEnforced
            self.outcomeJustification = "Alternative carrier rejected or non-operational under active Verizon lock policy. Normal enforcement verified."
            self.isPermanentUnlockVerified = false
        } else if cellularDataWorked && finalCarrierLock.localizedCaseInsensitiveContains("Locked") {
            self.classifiedOutcome = .alternateCarrierActivatedLockUnchanged
            self.outcomeJustification = "Alternative carrier connected while Settings displays SIM Locked. Warning: Does not constitute an unlock; requires verification of carrier bundle roaming."
            self.isPermanentUnlockVerified = false
        } else if !technicianNotes.isEmpty && technicianNotes.localizedCaseInsensitiveContains("anomaly") {
            self.classifiedOutcome = .unexpectedBehavior
            self.outcomeJustification = "Baseband or CommCenter exhibited unexpected behavior requiring deep IPC trace."
            self.isPermanentUnlockVerified = false
        } else {
            self.classifiedOutcome = .inconclusive
            self.outcomeJustification = "Observations insufficient for definitive classification."
            self.isPermanentUnlockVerified = false
        }
    }
}
