import XCTest
@testable import CarrierLab

final class Phase2ExperimentTests: XCTestCase {
    
    var tempDirectory: URL!
    var experimentManager: ExperimentManager!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        experimentManager = ExperimentManager(customBaseDirectory: tempDirectory)
    }
    
    override func tearDown() {
        if let dir = tempDirectory {
            try? FileManager.default.removeItem(at: dir)
        }
        super.tearDown()
    }
    
    func testBaselineCaptureCreationAndSeparation() {
        let diag = DeviceDiagnostics(
            productType: "iPhone19,4",
            productVersion: "27.2",
            buildVersion: "24B91020",
            basebandVersion: "1.02.05",
            basebandStatus: "BBInfoAvailable",
            activationState: "Activated",
            simStatus: "kCTSIMSupportSIMStatusReady",
            sanitizedUDID: "••••••••••••12AB"
        )
        
        let baseline = ExperimentBaseline.fromDiagnostics(
            diag,
            label: "Pre-Test Initial Baseline",
            ownerLockSetting: "SIM Locked",
            carrier: "Verizon",
            technician: "Lead-Researcher",
            notes: "Verified on test bench."
        )
        
        // 1. Verify device-observed telemetry
        XCTAssertEqual(baseline.observed.productType, "iPhone19,4")
        XCTAssertEqual(baseline.observed.buildVersion, "24B91020")
        XCTAssertEqual(baseline.observed.basebandVersion, "1.02.05")
        XCTAssertEqual(baseline.observed.simStatus, "kCTSIMSupportSIMStatusReady")
        
        // 2. Verify owner confirmed values
        XCTAssertEqual(baseline.ownerConfirmed.carrierLockSetting, "SIM Locked")
        XCTAssertEqual(baseline.ownerConfirmed.activeCarrier, "Verizon")
        
        // 3. Verify interpretation states that SIMStatusReady does not equal carrier unlock
        XCTAssertTrue(baseline.interpretation.simStatusAnalysis.contains("does NOT denote that the phone is carrier-unlocked"))
        
        // 4. Verify immutable SHA-256 snapshot checksum
        XCTAssertFalse(baseline.snapshotChecksum.isEmpty)
        XCTAssertEqual(baseline.snapshotChecksum.count, 64)
    }
    
    func testExperimentIntegrityAndTamperDetection() {
        let diag = DeviceDiagnostics(
            productType: "iPhone19,4",
            productVersion: "27.2",
            buildVersion: "24B91020",
            basebandVersion: "1.02.05",
            sanitizedUDID: "••••••••••••12AB"
        )
        let baseline = ExperimentBaseline.fromDiagnostics(diag)
        
        var experiment = CarrierExperiment(
            id: "EXP-TEST-001",
            redactedDeviceIdentifier: "••••••••••••12AB",
            initialBaseline: baseline,
            targetCarrier: "T-Mobile",
            eSIMInstalled: false,
            outcome: .carrierRestrictionEnforced
        )
        
        // Test integrity check passes on unmodified experiment
        XCTAssertTrue(experimentManager.verifyIntegrity(of: experiment))
        
        // Test tampering breaks integrity
        experiment.targetCarrier = "Tampered-Carrier"
        XCTAssertFalse(experimentManager.verifyIntegrity(of: experiment))
    }
    
    func testOutcomeClassification_CarrierRestrictionEnforced() {
        let diag = DeviceDiagnostics(productType: "iPhone19,4", buildVersion: "24B91020", basebandVersion: "1.02.05")
        let initial = ExperimentBaseline.fromDiagnostics(diag, ownerLockSetting: "SIM Locked")
        let final = ExperimentBaseline.fromDiagnostics(diag, ownerLockSetting: "SIM Locked")
        
        let comparison = ExperimentComparisonResult(
            initial: initial,
            final: final,
            eSIMInstalled: false,
            cellularDataWorked: false,
            rebootPersistenceConfirmed: false
        )
        
        XCTAssertEqual(comparison.classifiedOutcome, .carrierRestrictionEnforced)
        XCTAssertFalse(comparison.isPermanentUnlockVerified)
    }
    
    func testOutcomeClassification_AlternateCarrierActivatedLockUnchanged() {
        let diag = DeviceDiagnostics(productType: "iPhone19,4", buildVersion: "24B91020", basebandVersion: "1.02.05")
        let initial = ExperimentBaseline.fromDiagnostics(diag, ownerLockSetting: "SIM Locked")
        let final = ExperimentBaseline.fromDiagnostics(diag, ownerLockSetting: "SIM Locked")
        
        // Alternative carrier data worked, but Settings still reports SIM Locked
        let comparison = ExperimentComparisonResult(
            initial: initial,
            final: final,
            eSIMInstalled: true,
            cellularDataWorked: true,
            rebootPersistenceConfirmed: false
        )
        
        XCTAssertEqual(comparison.classifiedOutcome, .alternateCarrierActivatedLockUnchanged)
        // Must NOT equate temporary cellular connection with permanent unlock
        XCTAssertFalse(comparison.isPermanentUnlockVerified)
    }
    
    func testOutcomeClassification_StrictUnlockVerificationGate() {
        let diag = DeviceDiagnostics(productType: "iPhone19,4", buildVersion: "24B91020", basebandVersion: "1.02.05")
        let initial = ExperimentBaseline.fromDiagnostics(diag, ownerLockSetting: "SIM Locked")
        let final = ExperimentBaseline.fromDiagnostics(diag, ownerLockSetting: "No SIM Restrictions")
        
        // Case A: Settings reports No SIM Restrictions, but reboot persistence NOT confirmed
        let comparisonUnconfirmed = ExperimentComparisonResult(
            initial: initial,
            final: final,
            eSIMInstalled: true,
            cellularDataWorked: true,
            rebootPersistenceConfirmed: false
        )
        XCTAssertFalse(comparisonUnconfirmed.isPermanentUnlockVerified)
        
        // Case B: Settings reports No SIM Restrictions, AND reboot persistence IS confirmed
        let comparisonConfirmed = ExperimentComparisonResult(
            initial: initial,
            final: final,
            eSIMInstalled: true,
            cellularDataWorked: true,
            rebootPersistenceConfirmed: true
        )
        XCTAssertEqual(comparisonConfirmed.classifiedOutcome, .carrierLockChangedAuthorized)
        XCTAssertTrue(comparisonConfirmed.isPermanentUnlockVerified)
    }
    
    func testExperimentManager_PersistenceAndSilentOverwriteProtection() {
        let diag = DeviceDiagnostics(productType: "iPhone19,4")
        let baseline = ExperimentBaseline.fromDiagnostics(diag)
        let experiment = CarrierExperiment(
            id: "EXP-IMMUTABLE-001",
            redactedDeviceIdentifier: "••••••••••••12AB",
            initialBaseline: baseline,
            targetCarrier: "AT&T"
        )
        
        // Save initial
        XCTAssertNoThrow(try experimentManager.saveExperiment(experiment, allowOverwrite: false))
        
        // Attempting to overwrite without allowOverwrite must throw error 409
        XCTAssertThrowsError(try experimentManager.saveExperiment(experiment, allowOverwrite: false))
        
        // Loading all experiments
        let loaded = experimentManager.loadAllExperiments()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, "EXP-IMMUTABLE-001")
        XCTAssertEqual(loaded.first?.targetCarrier, "AT&T")
    }
    
    func testSafety_OriginalVerizonLineProtection() {
        let diag = DeviceDiagnostics(productType: "iPhone19,4")
        let baseline = ExperimentBaseline.fromDiagnostics(diag)
        let experiment = CarrierExperiment(
            redactedDeviceIdentifier: "••••••••••••12AB",
            initialBaseline: baseline,
            originalVerizonServiceIntact: true
        )
        
        XCTAssertTrue(experiment.originalVerizonServiceIntact)
        let md = experiment.formattedMarkdown()
        XCTAssertTrue(md.contains("Original Verizon eSIM Preserved: YES (Verified Intact)"))
    }
}
