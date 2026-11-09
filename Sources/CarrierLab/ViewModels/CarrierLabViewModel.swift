import Foundation
import Combine

public struct LogEntry: Identifiable, Equatable {
    public enum Level: String, Codable {
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
        case success = "SUCCESS"
    }
    
    public let id = UUID()
    public let timestamp: Date
    public let level: Level
    public let message: String
    
    public init(level: Level = .info, message: String) {
        self.timestamp = Date()
        self.level = level
        // Always scrub device IDs before logging
        self.message = DeviceSanitizer.sanitizeLogMessage(message)
    }
}

@MainActor
public final class CarrierLabViewModel: ObservableObject {
    
    // Published UI state
    @Published public var connectionStatus: ConnectionStatus = .disconnected
    @Published public var deviceDiagnostics: DeviceDiagnostics?
    @Published public var carrierLockConfirmation: CarrierLockConfirmation
    @Published public var diagnosticLogs: [LogEntry] = []
    @Published public var isScanning: Bool = false
    @Published public var lastExportPaths: (json: String, markdown: String)?
    @Published public var rawErrors: [String] = []
    
    // Selected discovery service
    public var discoveryService: DeviceDiscoveryProtocol
    
    // Host system info
    public var hostEnvironment: DiagnosticReport.HostEnvironmentInfo
    
    public init(
        discoveryService: DeviceDiscoveryProtocol = LibimobiledeviceCLIClient(),
        hostEnvironment: DiagnosticReport.HostEnvironmentInfo? = nil
    ) {
        self.discoveryService = discoveryService
        self.carrierLockConfirmation = CarrierLockConfirmation(
            confirmedState: .unconfirmed,
            financingStatus: .financedActive,
            carrierName: "Verizon",
            technicianID: "SecurityResearcher"
        )
        
        let host = hostEnvironment ?? DiagnosticReport.HostEnvironmentInfo(
            osName: "macOS",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            cpuArchitecture: {
                #if arch(arm64)
                return "Apple Silicon (arm64)"
                #elseif arch(x86_64)
                return "Intel (x86_64)"
                #else
                return "Unknown"
                #endif
            }(),
            developerTools: "Xcode Command Line Tools / Swift 5.9+",
            libimobiledeviceConfig: "libimobiledevice via Homebrew (/opt/homebrew/bin/ideviceinfo)"
        )
        self.hostEnvironment = host
        
        appendLog(level: .info, message: "CarrierLab initialized on \(host.osName) (\(host.cpuArchitecture)).")
    }
    
    public func appendLog(level: LogEntry.Level, message: String) {
        let entry = LogEntry(level: level, message: message)
        diagnosticLogs.append(entry)
        if level == .error {
            rawErrors.append("[\(entry.timestamp)] \(entry.message)")
        }
    }
    
    /// Triggers discovery and diagnostics extraction against the device.
    public func runDiagnostics() async {
        isScanning = true
        connectionStatus = .connecting
        appendLog(level: .info, message: "Initiating live device discovery via \(type(of: discoveryService))...")
        
        do {
            let daemonStatus = await discoveryService.checkDaemonStatus()
            switch daemonStatus {
            case .failure(let error):
                connectionStatus = .error(message: error.localizedDescription)
                appendLog(level: .error, message: error.localizedDescription)
                isScanning = false
                return
            case .success:
                break
            }
            
            let devices = try await discoveryService.discoverConnectedDevices()
            if devices.isEmpty {
                connectionStatus = .disconnected
                appendLog(level: .warning, message: "No USB-connected iOS devices detected. Please verify USB connection and Trust prompt.")
                deviceDiagnostics = nil
                isScanning = false
                return
            }
            
            let targetUDID = devices.first
            appendLog(level: .info, message: "Detected iOS device with UDID: \(targetUDID ?? "Unknown"). Querying lockdownd...")
            
            let diagnostics = try await discoveryService.retrieveDiagnostics(udid: targetUDID)
            self.deviceDiagnostics = diagnostics
            self.connectionStatus = .connected(interface: "USB (usbmuxd / lockdownd)")
            
            appendLog(level: .success, message: "Diagnostics acquired successfully.")
            appendLog(level: .info, message: "Hardware: \(diagnostics.displayProductType) | iOS: \(diagnostics.displayProductVersion) (Build \(diagnostics.displayBuildVersion)) | Modem: \(diagnostics.displayBasebandVersion)")
            
        } catch let error as DeviceDiscoveryError {
            connectionStatus = .error(message: error.localizedDescription)
            appendLog(level: .error, message: "Discovery error: \(error.localizedDescription)")
            deviceDiagnostics = nil
        } catch {
            connectionStatus = .error(message: error.localizedDescription)
            appendLog(level: .error, message: "Unexpected runtime failure: \(error.localizedDescription)")
            deviceDiagnostics = nil
        }
        
        isScanning = false
    }
    
    /// Updates manual carrier lock verification.
    public func confirmCarrierLock(
        state: CarrierLockConfirmation.LockState,
        carrierName: String,
        financing: CarrierLockConfirmation.FinancingStatus,
        technician: String,
        notes: String
    ) {
        self.carrierLockConfirmation = CarrierLockConfirmation(
            confirmedState: state,
            financingStatus: financing,
            carrierName: carrierName,
            technicianID: technician,
            verificationDate: Date(),
            settingsPathVerified: "Settings > General > About > Carrier Lock",
            notes: notes
        )
        appendLog(level: .success, message: "Carrier Lock status manually confirmed: \(state.rawValue) (\(carrierName), \(financing.rawValue)).")
    }
    
    /// Exports the local diagnostic report to disk.
    public func saveDiagnosticReport() throws -> (jsonURL: URL, markdownURL: URL) {
        let report = DiagnosticReport(
            hostEnvironment: hostEnvironment,
            connectionStatus: connectionStatus.displayText,
            deviceDiagnostics: deviceDiagnostics,
            manualTechnicianConfirmation: carrierLockConfirmation,
            rawDiagnosticsErrors: rawErrors,
            citedResearchNotes: """
            ### A. libimobiledevice:
            Non-invasive lockdown query over usbmuxd (/var/run/usbmuxd). Read-only telemetry interface.
            ### B. seemoo-lab/BaseTrace:
            AP-Baseband IPC tracing (QMI / ARI). Packet injection requires root/jailbreak.
            ### C. userlandkernel/baseband-research:
            Legacy 32-bit baseband architecture; obsolete for 64-bit hardware with Secure Boot.
            ### D. Cryptographic Carrier Lock Architecture:
            Enforced via Apple-signed Activation Records (WildcardTickets) verified by baseband boot ROM.
            """
        )
        
        let (jsonURL, mdURL) = try ReportExporter.exportReport(report)
        self.lastExportPaths = (json: jsonURL.path, markdown: mdURL.path)
        appendLog(level: .success, message: "Diagnostic report saved to: \(mdURL.lastPathComponent)")
        return (jsonURL, mdURL)
    }
}
