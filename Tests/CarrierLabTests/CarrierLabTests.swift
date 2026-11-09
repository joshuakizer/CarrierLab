import XCTest
@testable import CarrierLab

final class DeviceSanitizerTests: XCTestCase {
    
    func testUDIDSanitization() {
        let legacyUDID = "1234567890abcdef1234567890abcdef12345678"
        let sanitized = DeviceSanitizer.sanitizeUDID(legacyUDID)
        XCTAssertNotNil(sanitized)
        XCTAssertTrue(sanitized!.hasSuffix("5678"))
        XCTAssertFalse(sanitized!.contains("1234567890abcdef"))
        XCTAssertEqual(sanitized!.count, legacyUDID.count)
        
        let newUDID = "00008110-00192837465012AB"
        let sanitizedNew = DeviceSanitizer.sanitizeUDID(newUDID)
        XCTAssertNotNil(sanitizedNew)
        XCTAssertTrue(sanitizedNew!.hasSuffix("12AB"))
        XCTAssertFalse(sanitizedNew!.contains("00008110"))
    }
    
    func testIMEISanitization() {
        let imei = "353014109876543"
        let sanitized = DeviceSanitizer.sanitizeIMEI(imei)
        XCTAssertNotNil(sanitized)
        XCTAssertEqual(sanitized, "•••••••••••6543")
        XCTAssertFalse(sanitized!.contains("35301410"))
    }
    
    func testSerialNumberSanitization() {
        let serial = "F2LZA1B2C3D4"
        let sanitized = DeviceSanitizer.sanitizeSerialNumber(serial)
        XCTAssertNotNil(sanitized)
        XCTAssertEqual(sanitized, "•••••••••3D4")
    }
    
    func testNilAndEmptyHandling() {
        XCTAssertNil(DeviceSanitizer.sanitizeUDID(nil))
        XCTAssertNil(DeviceSanitizer.sanitizeUDID(""))
        XCTAssertNil(DeviceSanitizer.sanitizeIMEI(nil))
        XCTAssertNil(DeviceSanitizer.sanitizeIMEI("   "))
        XCTAssertNil(DeviceSanitizer.sanitizeSerialNumber(nil))
    }
    
    func testLogMessageScrubbing() {
        let rawLog = "Connecting to device 00008110-00192837465012AB with IMEI 353014109876543 via lockdownd"
        let scrubbed = DeviceSanitizer.sanitizeLogMessage(rawLog)
        XCTAssertFalse(scrubbed.contains("00008110-00192837465012AB"))
        XCTAssertFalse(scrubbed.contains("353014109876543"))
        XCTAssertTrue(scrubbed.contains("••••"))
    }
}

final class DeviceDiagnosticsTests: XCTestCase {
    
    func testUnavailableFieldsHandlingWithoutInventingValues() {
        let emptyDiag = DeviceDiagnostics()
        XCTAssertNil(emptyDiag.productType)
        XCTAssertNil(emptyDiag.productVersion)
        XCTAssertNil(emptyDiag.buildVersion)
        XCTAssertNil(emptyDiag.basebandVersion)
        
        // Display values must explicitly declare unavailable rather than hallucinating
        XCTAssertEqual(emptyDiag.displayProductType, "Unavailable / Not Reported")
        XCTAssertEqual(emptyDiag.displayProductVersion, "Unavailable / Not Reported")
        XCTAssertEqual(emptyDiag.displayBuildVersion, "Unavailable / Not Reported")
        XCTAssertEqual(emptyDiag.displayBasebandVersion, "Unavailable / Not Reported")
    }
    
    func testHardwareMarketingNameMapping() {
        let diag15 = DeviceDiagnostics(productType: "iPhone15,2")
        XCTAssertEqual(diag15.marketingName, "iPhone 14 Pro")
        
        let diag16 = DeviceDiagnostics(productType: "iPhone16,1")
        XCTAssertEqual(diag16.marketingName, "iPhone 15 Pro")
        
        let diagDuo = DeviceDiagnostics(
            productType: "iPhone19,4",
            productVersion: "27.2",
            buildVersion: "24B91020",
            basebandVersion: "1.02.05"
        )
        XCTAssertEqual(diagDuo.marketingName, "iPhone Duo")
        XCTAssertEqual(diagDuo.displayProductType, "iPhone19,4")
        XCTAssertEqual(diagDuo.displayProductVersion, "27.2")
        XCTAssertEqual(diagDuo.displayBuildVersion, "24B91020")
        XCTAssertEqual(diagDuo.displayBasebandVersion, "1.02.05")
        
        // Unmapped device should fallback to raw product type
        let unmapped = DeviceDiagnostics(productType: "CustomDevice,1")
        XCTAssertEqual(unmapped.marketingName, "CustomDevice,1")
    }
}

final class CarrierLockConfirmationTests: XCTestCase {
    
    func testManualConfirmationWorkflow() {
        var conf = CarrierLockConfirmation()
        XCTAssertFalse(conf.isConfirmed)
        XCTAssertEqual(conf.confirmedState, .unconfirmed)
        
        conf.confirmedState = .simLocked
        conf.carrierName = "Verizon"
        conf.verificationDate = Date()
        conf.technicianID = "Researcher-01"
        conf.notes = "Settings > General > About verified"
        
        XCTAssertTrue(conf.isConfirmed)
        XCTAssertEqual(conf.confirmedState, .simLocked)
        XCTAssertEqual(conf.carrierName, "Verizon")
    }
}

final class DiagnosticReportTests: XCTestCase {
    
    func testMarkdownReportGeneration() {
        let host = DiagnosticReport.HostEnvironmentInfo(
            osName: "macOS",
            osVersion: "15.1",
            cpuArchitecture: "arm64",
            developerTools: "Xcode 16.0",
            libimobiledeviceConfig: "libimobiledevice v1.3.0"
        )
        
        let diag = DeviceDiagnostics(
            productType: "iPhone15,2",
            productVersion: "17.5.1",
            buildVersion: "21F79",
            basebandVersion: "2.05.01",
            sanitizedUDID: "••••••••••••••••••••••••••••••••••••12AB"
        )
        
        let conf = CarrierLockConfirmation(
            confirmedState: .simLocked,
            carrierName: "Verizon",
            verificationDate: Date()
        )
        
        let report = DiagnosticReport(
            hostEnvironment: host,
            connectionStatus: "Connected via USB",
            deviceDiagnostics: diag,
            manualTechnicianConfirmation: conf,
            citedResearchNotes: "Verified cryptographic lock enforcement."
        )
        
        let markdown = report.formattedMarkdown()
        XCTAssertTrue(markdown.contains("# CarrierLab Diagnostic & Security Audit Report (Corrected)"))
        XCTAssertTrue(markdown.contains("Category A: Verified Through Executed Tests"))
        XCTAssertTrue(markdown.contains("Category B: Reported by Device Owner"))
        XCTAssertTrue(markdown.contains("Category C: Supported by Cited Public Research"))
        XCTAssertTrue(markdown.contains("Category D: Hypotheses Requiring Confirmation"))
        XCTAssertTrue(markdown.contains("iPhone15,2"))
        XCTAssertTrue(markdown.contains("17.5.1"))
        XCTAssertTrue(markdown.contains("SIM Locked"))
        XCTAssertTrue(markdown.contains("••••••••••••••••••••••••••••••••••••12AB"))
    }
}
