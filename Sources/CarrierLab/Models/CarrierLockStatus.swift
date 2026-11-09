import Foundation

/// Represents the manual confirmation and lockdownd observation of Carrier Lock status.
public struct CarrierLockConfirmation: Equatable, Codable {
    public enum LockState: String, CaseIterable, Codable {
        case unconfirmed = "Unconfirmed"
        case simLocked = "SIM Locked"
        case noSIMRestrictions = "No SIM Restrictions"
        case other = "Other / Unknown"
    }
    
    public enum FinancingStatus: String, CaseIterable, Codable {
        case unknown = "Unknown / Unverified"
        case financedActive = "Active Installment Plan / Financed"
        case fullyPaid = "Paid in Full / Unencumbered"
        case corporateFleet = "Corporate / Enterprise Managed"
    }
    
    public var confirmedState: LockState
    public var financingStatus: FinancingStatus
    public var carrierName: String
    public var technicianID: String
    public var verificationDate: Date?
    public var settingsPathVerified: String // e.g. "Settings > General > About > Carrier Lock"
    public var notes: String
    
    public init(
        confirmedState: LockState = .unconfirmed,
        financingStatus: FinancingStatus = .financedActive,
        carrierName: String = "Verizon",
        technicianID: String = "Researcher-01",
        verificationDate: Date? = nil,
        settingsPathVerified: String = "Settings > General > About > Carrier Lock",
        notes: String = ""
    ) {
        self.confirmedState = confirmedState
        self.financingStatus = financingStatus
        self.carrierName = carrierName
        self.technicianID = technicianID
        self.verificationDate = verificationDate
        self.settingsPathVerified = settingsPathVerified
        self.notes = notes
    }
    
    public var isConfirmed: Bool {
        return confirmedState != .unconfirmed && verificationDate != nil
    }
}
