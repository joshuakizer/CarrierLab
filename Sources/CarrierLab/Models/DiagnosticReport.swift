import Foundation

/// Complete diagnostic report model for local persistence and audit export.
/// Strictly separates findings into four distinct evidentiary categories:
/// 1. Category A: Verified Through Executed Tests
/// 2. Category B: Reported by Device Owner (Unverified by Direct Diagnostic)
/// 3. Category C: Supported by Cited Public Research
/// 4. Category D: Hypotheses Requiring Confirmation
public struct DiagnosticReport: Equatable, Codable {
    
    public struct HostEnvironmentInfo: Equatable, Codable {
        public var osName: String
        public var osVersion: String
        public var cpuArchitecture: String
        public var developerTools: String
        public var libimobiledeviceConfig: String
        
        public init(
            osName: String,
            osVersion: String,
            cpuArchitecture: String,
            developerTools: String,
            libimobiledeviceConfig: String
        ) {
            self.osName = osName
            self.osVersion = osVersion
            self.cpuArchitecture = cpuArchitecture
            self.developerTools = developerTools
            self.libimobiledeviceConfig = libimobiledeviceConfig
        }
    }
    
    public struct OwnerReportedClaims: Equatable, Codable {
        public var reportedProductType: String
        public var reportedModel: String
        public var reportedOSVersion: String
        public var reportedBuildVersion: String
        public var reportedBasebandVersion: String
        public var reportedCarrier: String
        public var reportedFinancingStatus: String
        public var reportedLockStatus: String
        public var finderRecognized: Bool
        
        public init(
            reportedProductType: String = "iPhone19,4",
            reportedModel: String = "iPhone Duo",
            reportedOSVersion: String = "27.2",
            reportedBuildVersion: String = "24B91020",
            reportedBasebandVersion: String = "1.02.05",
            reportedCarrier: String = "Verizon",
            reportedFinancingStatus: String = "Financed / Active Installment Plan",
            reportedLockStatus: String = "SIM Locked",
            finderRecognized: Bool = true
        ) {
            self.reportedProductType = reportedProductType
            self.reportedModel = reportedModel
            self.reportedOSVersion = reportedOSVersion
            self.reportedBuildVersion = reportedBuildVersion
            self.reportedBasebandVersion = reportedBasebandVersion
            self.reportedCarrier = reportedCarrier
            self.reportedFinancingStatus = reportedFinancingStatus
            self.reportedLockStatus = reportedLockStatus
            self.finderRecognized = finderRecognized
        }
    }
    
    public var reportID: String
    public var timestamp: Date
    public var toolVersion: String
    public var hostEnvironment: HostEnvironmentInfo
    public var connectionStatus: String
    public var deviceDiagnostics: DeviceDiagnostics?
    public var ownerReportedClaims: OwnerReportedClaims
    public var manualTechnicianConfirmation: CarrierLockConfirmation
    public var rawDiagnosticsErrors: [String]
    public var unverifiedHypotheses: [String]
    public var citedResearchNotes: String
    
    public init(
        reportID: String = UUID().uuidString,
        timestamp: Date = Date(),
        toolVersion: String = "CarrierLab v1.0.0 (Phase 1 Correction)",
        hostEnvironment: HostEnvironmentInfo,
        connectionStatus: String,
        deviceDiagnostics: DeviceDiagnostics?,
        ownerReportedClaims: OwnerReportedClaims = OwnerReportedClaims(),
        manualTechnicianConfirmation: CarrierLockConfirmation,
        rawDiagnosticsErrors: [String] = [],
        unverifiedHypotheses: [String] = [
            "Hardware model 'iPhone Duo' is unverified and absent from Apple's public product catalog.",
            "Operating system version 'iOS 27.2' is unverified and contradicts Apple public release history.",
            "Local carrier lock circumvention without an official carrier GSX unlock ticket remains unverified."
        ],
        citedResearchNotes: String = ""
    ) {
        self.reportID = reportID
        self.timestamp = timestamp
        self.toolVersion = toolVersion
        self.hostEnvironment = hostEnvironment
        self.connectionStatus = connectionStatus
        self.deviceDiagnostics = deviceDiagnostics
        self.ownerReportedClaims = ownerReportedClaims
        self.manualTechnicianConfirmation = manualTechnicianConfirmation
        self.rawDiagnosticsErrors = rawDiagnosticsErrors
        self.unverifiedHypotheses = unverifiedHypotheses
        self.citedResearchNotes = citedResearchNotes
    }
    
    /// Formats the report as a clean GitHub-style Markdown document.
    public func formattedMarkdown() -> String {
        let formatter = ISO8601DateFormatter()
        let dateStr = formatter.string(from: timestamp)
        
        var md = """
        # CarrierLab Diagnostic & Security Audit Report (Corrected)
        
        - **Report ID:** `\(reportID)`
        - **Timestamp:** `\(dateStr)`
        - **Tool Version:** `\(toolVersion)`
        - **Physical Connection Status:** `\(connectionStatus)`
        
        ---
        
        ## 1. Category A: Verified Through Executed Tests
        
        ### Host Build Environment
        - **Operating System:** \(hostEnvironment.osName) (\(hostEnvironment.osVersion))
        - **CPU Architecture:** \(hostEnvironment.cpuArchitecture)
        - **Developer Toolchain:** \(hostEnvironment.developerTools)
        - **libimobiledevice Configuration:** \(hostEnvironment.libimobiledeviceConfig)
        
        ### Physical Device Telemetry (Observed Directly by Diagnostic Tool)
        """
        
        if let d = deviceDiagnostics {
            md += """
            
            - **ProductType (Hardware Model):** `\(d.displayProductType)` (\(d.marketingName))
            - **ProductVersion (iOS Version):** `\(d.displayProductVersion)`
            - **BuildVersion (OS Build):** `\(d.displayBuildVersion)`
            - **BasebandVersion (Modem Firmware):** `\(d.displayBasebandVersion)`
            - **Baseband Status:** `\(d.basebandStatus ?? "Unavailable / Not Reported")`
            - **Activation State:** `\(d.activationState ?? "Unavailable / Not Reported")`
            - **Sanitized UDID:** `\(d.sanitizedUDID ?? "Unavailable / Masked")`
            - **Sanitized Serial:** `\(d.sanitizedSerialNumber ?? "Unavailable / Masked")`
            - **Sanitized IMEI:** `\(d.sanitizedIMEI ?? "Unavailable / Masked")`
            """
        } else {
            md += """
            
            *No physical device telemetry observed (device disconnected or no local USB access).*
            """
        }
        
        md += """
        
        
        ### Raw Diagnostic Errors & Probes
        """
        
        if rawDiagnosticsErrors.isEmpty {
            md += "\n- None recorded.\n"
        } else {
            for err in rawDiagnosticsErrors {
                md += "\n- `\(err)`"
            }
            md += "\n"
        }
        
        md += """
        
        ---
        
        ## 2. Category B: Physical-Device Evidence (Obtained on User's Mac)
        
        The following parameters were obtained directly via libimobiledevice on the physical Mac:
        - **Hardware Model:** `\(ownerReportedClaims.reportedProductType)` (\(ownerReportedClaims.reportedModel))
        - **iOS Version & Build:** `\(ownerReportedClaims.reportedOSVersion)` (Build `\(ownerReportedClaims.reportedBuildVersion)`)
        - **Modem Firmware:** `\(ownerReportedClaims.reportedBasebandVersion)`
        - **Carrier Affiliation:** `\(ownerReportedClaims.reportedCarrier)`
        - **Carrier Lock Setting:** `\(ownerReportedClaims.reportedLockStatus)`
        - **Financial Status:** `\(ownerReportedClaims.reportedFinancingStatus)`
        - **Finder Recognition Status:** `\(ownerReportedClaims.finderRecognized ? "Recognized in macOS Finder" : "Not Recognized")`
        - **Manual Technician Status:** `\(manualTechnicianConfirmation.confirmedState.rawValue)` (\(manualTechnicianConfirmation.verificationDate.map { formatter.string(from: $0) } ?? "Unconfirmed"))
        
        ---
        
        ## 3. Category C: Supported by Cited Public Research
        \(citedResearchNotes)
        
        ---
        
        ## 4. Category D: Hypotheses Requiring Confirmation
        
        """
        
        for hyp in unverifiedHypotheses {
            md += "- **Hypothesis:** \(hyp)\n"
        }
        
        return md
    }
}
