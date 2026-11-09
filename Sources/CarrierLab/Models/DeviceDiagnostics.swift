import Foundation

/// Represents the connection state of the diagnostic device interface.
public enum ConnectionStatus: Equatable, Hashable, Codable {
    case disconnected
    case connecting
    case connected(interface: String)
    case error(message: String)
    
    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
    
    public var displayText: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Searching for Device..."
        case .connected(let interface):
            return "Connected via \(interface)"
        case .error(let msg):
            return "Connection Error: \(msg)"
        }
    }
}

/// Holds device diagnostic parameters retrieved from lockdownd.
/// Handles unavailable fields gracefully without fabricating values.
public struct DeviceDiagnostics: Equatable, Codable {
    // Core hardware and firmware identifiers
    public var productType: String?
    public var productVersion: String?
    public var buildVersion: String?
    public var basebandVersion: String?
    
    // Supplemental lockdownd attributes
    public var deviceClass: String?
    public var modelNumber: String?
    public var basebandStatus: String?
    public var activationState: String?
    public var simStatus: String?
    public var wifiAddress: String?
    public var bluetoothAddress: String?
    
    // Privacy-sanitized identifiers (never expose full UDID/IMEI/Serial)
    public var sanitizedUDID: String?
    public var sanitizedSerialNumber: String?
    public var sanitizedIMEI: String?
    
    // Raw key-value pairs captured during lockdownd query
    public var rawProperties: [String: String]
    
    // Timestamp of query
    public var queryTimestamp: Date
    
    public init(
        productType: String? = nil,
        productVersion: String? = nil,
        buildVersion: String? = nil,
        basebandVersion: String? = nil,
        deviceClass: String? = nil,
        modelNumber: String? = nil,
        basebandStatus: String? = nil,
        activationState: String? = nil,
        simStatus: String? = nil,
        wifiAddress: String? = nil,
        bluetoothAddress: String? = nil,
        sanitizedUDID: String? = nil,
        sanitizedSerialNumber: String? = nil,
        sanitizedIMEI: String? = nil,
        rawProperties: [String: String] = [:],
        queryTimestamp: Date = Date()
    ) {
        self.productType = productType
        self.productVersion = productVersion
        self.buildVersion = buildVersion
        self.basebandVersion = basebandVersion
        self.deviceClass = deviceClass
        self.modelNumber = modelNumber
        self.basebandStatus = basebandStatus
        self.activationState = activationState
        self.simStatus = simStatus
        self.wifiAddress = wifiAddress
        self.bluetoothAddress = bluetoothAddress
        self.sanitizedUDID = sanitizedUDID
        self.sanitizedSerialNumber = sanitizedSerialNumber
        self.sanitizedIMEI = sanitizedIMEI
        self.rawProperties = rawProperties
        self.queryTimestamp = queryTimestamp
    }
    
    /// User-facing display value for ProductType.
    public var displayProductType: String {
        productType ?? "Unavailable / Not Reported"
    }
    
    /// User-facing display value for ProductVersion (iOS version).
    public var displayProductVersion: String {
        productVersion ?? "Unavailable / Not Reported"
    }
    
    /// User-facing display value for BuildVersion.
    public var displayBuildVersion: String {
        buildVersion ?? "Unavailable / Not Reported"
    }
    
    /// User-facing display value for BasebandVersion (Modem Firmware).
    public var displayBasebandVersion: String {
        basebandVersion ?? "Unavailable / Not Reported"
    }
    
    /// Friendly marketing name mapping where known, or falls back to raw ProductType.
    public var marketingName: String {
        guard let pt = productType else { return "Unknown Apple Device" }
        switch pt {
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
        case "iPhone19,4": return "iPhone Duo"
        default:
            return pt
        }
    }
}
