import Foundation

/// Bridge to libimobiledevice CLI utilities (`idevice_id` and `ideviceinfo`).
public final class LibimobiledeviceCLIClient: DeviceDiscoveryProtocol {
    
    private let searchPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin"
    ]
    
    public init() {}
    
    public func resolveExecutable(_ name: String) -> String? {
        let fm = FileManager.default
        for path in searchPaths {
            let full = "\(path)/\(name)"
            if fm.isExecutableFile(atPath: full) {
                return full
            }
        }
        return nil
    }
    
    public func checkDaemonStatus() async -> Result<Bool, DeviceDiscoveryError> {
        guard resolveExecutable("ideviceinfo") != nil else {
            return .failure(.usbmuxdUnavailable(reason: "libimobiledevice binary 'ideviceinfo' was not found in PATH or standard directories."))
        }
        return .success(true)
    }
    
    public func discoverConnectedDevices() async throws -> [String] {
        guard let ideviceIdPath = resolveExecutable("idevice_id") else {
            // Fallback: check ideviceinfo directly
            guard let ideviceinfoPath = resolveExecutable("ideviceinfo") else {
                throw DeviceDiscoveryError.usbmuxdUnavailable(reason: "Neither idevice_id nor ideviceinfo was found.")
            }
            let (status, output, _) = runProcess(executable: ideviceinfoPath, arguments: ["-k", "UniqueDeviceID"])
            if status == 0, !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return [output.trimmingCharacters(in: .whitespacesAndNewlines)]
            }
            return []
        }
        
        let (status, output, err) = runProcess(executable: ideviceIdPath, arguments: ["-l"])
        guard status == 0 else {
            if err.contains("No device found") || output.isEmpty {
                return []
            }
            throw DeviceDiscoveryError.commandFailed(exitCode: status, stderr: err)
        }
        
        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines
    }
    
    public func retrieveDiagnostics(udid: String? = nil) async throws -> DeviceDiagnostics {
        guard let ideviceinfoPath = resolveExecutable("ideviceinfo") else {
            throw DeviceDiscoveryError.usbmuxdUnavailable(reason: "ideviceinfo binary is not installed.")
        }
        
        var args: [String] = []
        if let targetUdid = udid, !targetUdid.isEmpty {
            args.append(contentsOf: ["-u", targetUdid])
        }
        
        let (status, output, err) = runProcess(executable: ideviceinfoPath, arguments: args)
        guard status == 0 else {
            if err.contains("No device found") || output.isEmpty {
                throw DeviceDiscoveryError.deviceNotFound
            }
            if err.contains("PasswordProtected") || output.contains("PasswordProtected") {
                throw DeviceDiscoveryError.deviceLockedWithPasscode
            }
            if err.contains("PairingDialogResponsePending") || output.contains("Pairing") {
                throw DeviceDiscoveryError.pairingRequired
            }
            throw DeviceDiscoveryError.commandFailed(exitCode: status, stderr: err)
        }
        
        return parseIdeviceInfoOutput(output)
    }
    
    public func parseIdeviceInfoOutput(_ output: String) -> DeviceDiagnostics {
        var rawProps: [String: String] = [:]
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                rawProps[key] = value
            }
        }
        
        let productType = rawProps["ProductType"]?.isEmpty == false ? rawProps["ProductType"] : nil
        let productVersion = rawProps["ProductVersion"]?.isEmpty == false ? rawProps["ProductVersion"] : nil
        let buildVersion = rawProps["BuildVersion"]?.isEmpty == false ? rawProps["BuildVersion"] : nil
        let basebandVersion = rawProps["BasebandVersion"]?.isEmpty == false ? rawProps["BasebandVersion"] : nil
        let basebandStatus = rawProps["BasebandStatus"]?.isEmpty == false ? rawProps["BasebandStatus"] : nil
        let activationState = rawProps["ActivationState"]?.isEmpty == false ? rawProps["ActivationState"] : nil
        let deviceClass = rawProps["DeviceClass"]?.isEmpty == false ? rawProps["DeviceClass"] : nil
        let modelNumber = rawProps["ModelNumber"]?.isEmpty == false ? rawProps["ModelNumber"] : nil
        let simStatus = rawProps["SIMStatus"]?.isEmpty == false ? rawProps["SIMStatus"] : nil
        let wifiAddress = rawProps["WiFiAddress"]?.isEmpty == false ? rawProps["WiFiAddress"] : nil
        let bluetoothAddress = rawProps["BluetoothAddress"]?.isEmpty == false ? rawProps["BluetoothAddress"] : nil
        
        let rawUDID = rawProps["UniqueDeviceID"]
        let rawSerial = rawProps["SerialNumber"]
        let rawIMEI = rawProps["InternationalMobileEquipmentIdentity"]
        
        return DeviceDiagnostics(
            productType: productType,
            productVersion: productVersion,
            buildVersion: buildVersion,
            basebandVersion: basebandVersion,
            deviceClass: deviceClass,
            modelNumber: modelNumber,
            basebandStatus: basebandStatus,
            activationState: activationState,
            simStatus: simStatus,
            wifiAddress: wifiAddress,
            bluetoothAddress: bluetoothAddress,
            sanitizedUDID: DeviceSanitizer.sanitizeUDID(rawUDID),
            sanitizedSerialNumber: DeviceSanitizer.sanitizeSerialNumber(rawSerial),
            sanitizedIMEI: DeviceSanitizer.sanitizeIMEI(rawIMEI),
            rawProperties: rawProps,
            queryTimestamp: Date()
        )
    }
    
    private func runProcess(executable: String, arguments: [String]) -> (Int32, String, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            
            let outStr = String(data: outData, encoding: .utf8) ?? ""
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            
            return (process.terminationStatus, outStr, errStr)
        } catch {
            return (-1, "", error.localizedDescription)
        }
    }
}
