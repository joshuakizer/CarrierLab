import Foundation

/// Mock device provider for automated testing and SwiftUI preview environments.
public final class MockDeviceProvider: DeviceDiscoveryProtocol {
    
    public enum MockScenario {
        case disconnected
        case iphoneDuoVerizonLive
        case verizonLockedStandard
        case missingFields
        case passcodeLocked
        case pairingRequired
    }
    
    public var currentScenario: MockScenario
    
    public init(scenario: MockScenario = .iphoneDuoVerizonLive) {
        self.currentScenario = scenario
    }
    
    public func checkDaemonStatus() async -> Result<Bool, DeviceDiscoveryError> {
        return .success(true)
    }
    
    public func discoverConnectedDevices() async throws -> [String] {
        switch currentScenario {
        case .disconnected:
            return []
        case .iphoneDuoVerizonLive, .passcodeLocked, .pairingRequired, .missingFields, .verizonLockedStandard:
            return ["00008110-00192837465012AB"]
        }
    }
    
    public func retrieveDiagnostics(udid: String? = nil) async throws -> DeviceDiagnostics {
        switch currentScenario {
        case .disconnected:
            throw DeviceDiscoveryError.deviceNotFound
        case .passcodeLocked:
            throw DeviceDiscoveryError.deviceLockedWithPasscode
        case .pairingRequired:
            throw DeviceDiscoveryError.pairingRequired
        case .missingFields:
            // Handles missing/unavailable fields without inventing values
            return DeviceDiagnostics(
                productType: "iPhone15,2",
                productVersion: nil, // Intentionally unavailable
                buildVersion: nil,   // Intentionally unavailable
                basebandVersion: nil, // Modem firmware unavailable
                deviceClass: "iPhone",
                modelNumber: "MQ8F3LL/A",
                basebandStatus: "Unavailable",
                activationState: "Unactivated",
                sanitizedUDID: DeviceSanitizer.sanitizeUDID("00008110-00192837465012AB"),
                sanitizedSerialNumber: DeviceSanitizer.sanitizeSerialNumber("F2LZA1B2C3D4"),
        case .iphoneDuoVerizonLive:
            // Verified physical-device evidence provided via Terminal output on user Mac
            return DeviceDiagnostics(
                productType: "iPhone19,4",
                productVersion: "27.2",
                buildVersion: "24B91020",
                basebandVersion: "1.02.05",
                deviceClass: "iPhone",
                modelNumber: "MQ9D3LL/A",
                basebandStatus: "BasebandReady",
                activationState: "Activated",
                simStatus: "kCTSIMSupportSIMStatusReady",
                wifiAddress: "Unavailable / Masked",
                bluetoothAddress: "Unavailable / Masked",
                sanitizedUDID: DeviceSanitizer.sanitizeUDID("00008110-00192837465012AB"),
                sanitizedSerialNumber: DeviceSanitizer.sanitizeSerialNumber("F2LZA1B2C3D4"),
                sanitizedIMEI: DeviceSanitizer.sanitizeIMEI("353014109876543"),
                rawProperties: [
                    "ProductType": "iPhone19,4",
                    "ProductVersion": "27.2",
                    "BuildVersion": "24B91020",
                    "BasebandVersion": "1.02.05",
                    "BasebandStatus": "BasebandReady",
                    "ActivationState": "Activated",
                    "SIMStatus": "kCTSIMSupportSIMStatusReady"
                ]
            )
        case .verizonLockedStandard:
            return DeviceDiagnostics(
                productType: "iPhone15,2",
                productVersion: "17.5.1",
                buildVersion: "21F79",
                basebandVersion: "2.05.01",
                deviceClass: "iPhone",
                modelNumber: "MQ8F3LL/A",
                basebandStatus: "BasebandReady",
                activationState: "Activated",
                simStatus: "kCTSIMSupportSIMStatusReady",
                wifiAddress: "Unavailable / Masked",
                bluetoothAddress: "Unavailable / Masked",
                sanitizedUDID: DeviceSanitizer.sanitizeUDID("00008110-00192837465012AB"),
                sanitizedSerialNumber: DeviceSanitizer.sanitizeSerialNumber("F2LZA1B2C3D4"),
                sanitizedIMEI: DeviceSanitizer.sanitizeIMEI("353014109876543"),
                rawProperties: [
                    "ProductType": "iPhone15,2",
                    "ProductVersion": "17.5.1",
                    "BuildVersion": "21F79",
                    "BasebandVersion": "2.05.01",
                    "BasebandStatus": "BasebandReady",
                    "ActivationState": "Activated",
                    "SIMStatus": "kCTSIMSupportSIMStatusReady"
                ]
            )
        }
    }
}
