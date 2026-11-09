import Foundation

public enum DeviceDiscoveryError: LocalizedError, Equatable {
    case usbmuxdUnavailable(reason: String)
    case deviceNotFound
    case deviceLockedWithPasscode
    case pairingRequired
    case commandFailed(exitCode: Int32, stderr: String)
    case parsingFailed(reason: String)
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .usbmuxdUnavailable(let reason):
            return "usbmuxd daemon socket unavailable: \(reason)"
        case .deviceNotFound:
            return "No connected iOS device detected via USB/usbmuxd."
        case .deviceLockedWithPasscode:
            return "Device is locked with passcode. Please unlock and trust this computer."
        case .pairingRequired:
            return "Host pairing not established. Trust prompt must be accepted on device."
        case .commandFailed(let code, let err):
            return "Diagnostics command exited with code \(code): \(err)"
        case .parsingFailed(let reason):
            return "Failed to parse lockdown response: \(reason)"
        case .timeout:
            return "Device query timed out."
        }
    }
}

/// Abstract protocol for discovering connected devices and fetching diagnostics.
public protocol DeviceDiscoveryProtocol {
    func checkDaemonStatus() async -> Result<Bool, DeviceDiscoveryError>
    func discoverConnectedDevices() async throws -> [String]
    func retrieveDiagnostics(udid: String?) async throws -> DeviceDiagnostics
}

extension DeviceDiscoveryProtocol {
    /// Convenience asynchronous property to determine whether at least one device is currently connected.
    public var isConnected: Bool {
        get async {
            let devices = (try? await discoverConnectedDevices()) ?? []
            return !devices.isEmpty
        }
    }
    
    /// Returns whether at least one iOS device is currently detected via this discovery service.
    public func isDeviceConnected() async -> Bool {
        let devices = (try? await discoverConnectedDevices()) ?? []
        return !devices.isEmpty
    }
}
