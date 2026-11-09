import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Communicates directly with Apple's usbmuxd daemon via UNIX domain socket.
/// Implements standard usbmux protocol v1 (plist-based) over /var/run/usbmuxd.
public final class NativeUSBMuxdClient: DeviceDiscoveryProtocol {
    public let socketPath: String
    
    public init(socketPath: String = "/var/run/usbmuxd") {
        self.socketPath = socketPath
    }
    
    public func checkDaemonStatus() async -> Result<Bool, DeviceDiscoveryError> {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: socketPath) {
            return .failure(.usbmuxdUnavailable(reason: "UNIX socket not found at \(socketPath). usbmuxd is not running."))
        }
        return .success(true)
    }
    
    /// Connects to /var/run/usbmuxd, transmits a ListDevices plist request, and parses connected UDIDs.
    public func discoverConnectedDevices() async throws -> [String] {
        guard case .success = await checkDaemonStatus() else {
            throw DeviceDiscoveryError.usbmuxdUnavailable(reason: "Socket \(socketPath) is not accessible.")
        }
        
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw DeviceDiscoveryError.usbmuxdUnavailable(reason: "Failed to allocate UNIX domain socket (errno: \(errno)).")
        }
        defer { close(fd) }
        
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count < MemoryLayout.size(ofValue: addr.sun_path) else {
            throw DeviceDiscoveryError.usbmuxdUnavailable(reason: "Socket path exceeds sockaddr_un buffer.")
        }
        
        withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            _ = pathBytes.withUnsafeBufferPointer { buf in
                memcpy(ptr, buf.baseAddress!, buf.count)
            }
        }
        
        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                connect(fd, saPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        
        guard connectResult == 0 else {
            throw DeviceDiscoveryError.usbmuxdUnavailable(reason: "Failed to connect to \(socketPath) (errno: \(errno)).")
        }
        
        // Prepare usbmux ListDevices plist payload
        let requestDict: [String: Any] = [
            "MessageType": "ListDevices",
            "ClientVersionString": "CarrierLab-v1.0",
            "ProgName": "CarrierLab"
        ]
        
        let plistData = try PropertyListSerialization.data(fromPropertyList: requestDict, format: .xml, options: 0)
        
        // Header: 16 bytes: Length (uint32), Version (uint32 = 1), Request (uint32 = 8 for Plist), Tag (uint32 = 1)
        var totalLength = UInt32(16 + plistData.count).littleEndian
        var version = UInt32(1).littleEndian
        var request = UInt32(8).littleEndian
        var tag = UInt32(1).littleEndian
        
        var packet = Data()
        packet.append(Data(bytes: &totalLength, count: 4))
        packet.append(Data(bytes: &version, count: 4))
        packet.append(Data(bytes: &request, count: 4))
        packet.append(Data(bytes: &tag, count: 4))
        packet.append(plistData)
        
        let written = packet.withUnsafeBytes { rawBuf in
            write(fd, rawBuf.baseAddress!, rawBuf.count)
        }
        guard written == packet.count else {
            throw DeviceDiscoveryError.commandFailed(exitCode: -1, stderr: "Short write to usbmuxd socket.")
        }
        
        // Read response header (16 bytes)
        var headerBuf = [UInt8](repeating: 0, count: 16)
        let headerRead = read(fd, &headerBuf, 16)
        guard headerRead == 16 else {
            throw DeviceDiscoveryError.parsingFailed(reason: "Invalid response header from usbmuxd.")
        }
        
        let respLength = headerBuf.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }.littleEndian
        guard respLength >= 16 else {
            throw DeviceDiscoveryError.parsingFailed(reason: "Payload length too small.")
        }
        
        let payloadSize = Int(respLength - 16)
        var payloadBuf = [UInt8](repeating: 0, count: payloadSize)
        var totalRead = 0
        while totalRead < payloadSize {
            let r = read(fd, &payloadBuf[totalRead], payloadSize - totalRead)
            if r <= 0 { break }
            totalRead += r
        }
        
        guard totalRead == payloadSize else {
            throw DeviceDiscoveryError.parsingFailed(reason: "Incomplete payload received from usbmuxd.")
        }
        
        let respData = Data(payloadBuf)
        guard let plistObj = try? PropertyListSerialization.propertyList(from: respData, options: [], format: nil),
              let dict = plistObj as? [String: Any] else {
            throw DeviceDiscoveryError.parsingFailed(reason: "Failed to deserialize usbmuxd response plist.")
        }
        
        var detectedUDIDs: [String] = []
        if let deviceList = dict["DeviceList"] as? [[String: Any]] {
            for entry in deviceList {
                if let props = entry["Properties"] as? [String: Any],
                   let serial = props["SerialNumber"] as? String {
                    detectedUDIDs.append(serial)
                }
            }
        }
        
        return detectedUDIDs
    }
    
    public func retrieveDiagnostics(udid: String?) async throws -> DeviceDiagnostics {
        guard case .success = await checkDaemonStatus() else {
            throw DeviceDiscoveryError.usbmuxdUnavailable(reason: "Socket \(socketPath) is not accessible.")
        }
        
        let devices = try await discoverConnectedDevices()
        if devices.isEmpty {
            throw DeviceDiscoveryError.deviceNotFound
        }
        
        // Return diagnostics populated with observed UDID
        let activeUDID = udid ?? devices.first
        return DeviceDiagnostics(
            sanitizedUDID: DeviceSanitizer.sanitizeUDID(activeUDID),
            queryTimestamp: Date()
        )
    }
}
