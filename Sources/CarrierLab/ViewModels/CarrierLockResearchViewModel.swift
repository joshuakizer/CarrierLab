import Foundation
import Combine

public enum ExperimentStep: String, CaseIterable, Identifiable {
    case baselineCapture = "1. Capture Baseline"
    case testSetup = "2. eSIM Test Setup"
    case recordingResults = "3. Record Observations"
    case postTestVerify = "4. Post-Test Verification"
    case comparison = "5. Compare Results"
    case completed = "6. Export Evidence"
    
    public var id: String { rawValue }
}

@MainActor
public final class CarrierLockResearchViewModel: ObservableObject {
    
    // Core Dependencies
    public let discoveryService: DeviceDiscoveryProtocol
    public let experimentManager: ExperimentManager
    
    // Published UI State
    @Published public var activeStep: ExperimentStep = .baselineCapture
    @Published public var currentBaseline: ExperimentBaseline?
    @Published public var postTestBaseline: ExperimentBaseline?
    @Published public var currentExperiment: CarrierExperiment?
    @Published public var comparisonResult: ExperimentComparisonResult?
    @Published public var savedExperiments: [CarrierExperiment] = []
    
    // Form Inputs
    @Published public var targetCarrier: String = "T-Mobile"
    @Published public var manualLockSetting: String = "SIM Locked"
    @Published public var postTestManualLockSetting: String = "SIM Locked"
    @Published public var technicianID: String = "Lead-Security-Researcher"
    @Published public var technicianNotes: String = ""
    @Published public var observedErrorText: String = "SIM Not Supported: The SIM card that you currently have installed in this iPhone is from a carrier that is not supported under the activation policy."
    
    // Test Observation Flags
    @Published public var eSIMInstalled: Bool = false
    @Published public var cellularRegistrationOccurred: Bool = false
    @Published public var cellularDataWorked: Bool = false
    @Published public var testCallSucceeded: Bool = false
    @Published public var originalVerizonIntact: Bool = true
    @Published public var rebootPersistenceVerified: Bool = false
    
    // Runtime status
    @Published public var isProcessing: Bool = false
    @Published public var statusMessage: String?
    @Published public var errorMessage: String?
    
    public init(
        discoveryService: DeviceDiscoveryProtocol = LibimobiledeviceCLIClient(),
        experimentManager: ExperimentManager = .shared
    ) {
        self.discoveryService = discoveryService
        self.experimentManager = experimentManager
        loadExperimentHistory()
    }
    
    public func loadExperimentHistory() {
        self.savedExperiments = experimentManager.loadAllExperiments()
    }
    
    // MARK: - Control 1: Capture Baseline
    public func captureBaseline() async {
        isProcessing = true
        statusMessage = "Capturing pre-test hardware baseline via read-only interface..."
        errorMessage = nil
        
        do {
            let diagnostics = try await discoveryService.retrieveDiagnostics(udid: nil)
            let baseline = ExperimentBaseline.fromDiagnostics(
                diagnostics,
                label: "Pre-Test Initial Baseline",
                ownerLockSetting: manualLockSetting,
                carrier: "Verizon",
                technician: technicianID,
                notes: technicianNotes
            )
            self.currentBaseline = baseline
            self.statusMessage = "Baseline captured: \(baseline.observed.productType ?? "Device") | iOS \(baseline.observed.productVersion ?? "") | Modem \(baseline.observed.basebandVersion ?? "")."
            self.activeStep = .testSetup
        } catch {
            self.errorMessage = "Failed to capture baseline: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    // MARK: - Control 2: Begin eSIM Compatibility Test
    public func beginTest(targetCarrier: String) {
        guard let baseline = currentBaseline else {
            errorMessage = "Please capture an initial baseline before starting the test."
            return
        }
        
        self.targetCarrier = targetCarrier
        self.currentExperiment = CarrierExperiment(
            redactedDeviceIdentifier: baseline.observed.sanitizedUDID ?? "••••••••••••19,4",
            initialBaseline: baseline,
            targetCarrier: targetCarrier,
            activationMethod: "iOS Settings > Cellular > Add eSIM > Supported Carrier Setup"
        )
        self.activeStep = .recordingResults
        self.statusMessage = "eSIM Compatibility test initialized for \(targetCarrier). Follow on-device setup."
    }
    
    // MARK: - Control 3: Record Test Result
    public func recordTestObservations() {
        guard var exp = currentExperiment else {
            errorMessage = "No active experiment session found."
            return
        }
        
        var errors: [String] = []
        if !observedErrorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors = observedErrorText.components(separatedBy: .newlines).filter { !$0.isEmpty }
        }
        
        exp.eSIMInstalled = self.eSIMInstalled
        exp.cellularRegistrationOccurred = self.cellularRegistrationOccurred
        exp.cellularDataWorked = self.cellularDataWorked
        exp.testCallSucceeded = self.testCallSucceeded
        exp.originalVerizonServiceIntact = self.originalVerizonIntact
        exp.exactErrorMessages = errors
        exp.researcherNotes = self.technicianNotes
        
        self.currentExperiment = exp
        self.activeStep = .postTestVerify
        self.statusMessage = "Observations recorded. Proceed to post-test diagnostic snapshot."
    }
    
    // MARK: - Control 4: Verify After Test
    public func verifyAfterTest() async {
        guard let initial = currentBaseline else {
            errorMessage = "Missing initial baseline."
            return
        }
        
        isProcessing = true
        statusMessage = "Retrieving post-test hardware telemetry..."
        
        do {
            let diagnostics = try await discoveryService.retrieveDiagnostics(udid: nil)
            let final = ExperimentBaseline.fromDiagnostics(
                diagnostics,
                label: "Post-Test Verification Snapshot",
                ownerLockSetting: postTestManualLockSetting,
                carrier: "Verizon",
                technician: technicianID,
                notes: "Captured immediately following \(targetCarrier) eSIM test."
            )
            self.postTestBaseline = final
            self.currentExperiment?.finalBaseline = final
            
            // Run Comparison
            self.compareResults(initial: initial, final: final)
            self.activeStep = .comparison
            self.statusMessage = "Post-test baseline captured. Comparison diff generated."
        } catch {
            self.errorMessage = "Failed to query device after test: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    // MARK: - Control 5: Compare Results
    public func compareResults(initial: ExperimentBaseline, final: ExperimentBaseline) {
        let comp = ExperimentComparisonResult(
            initial: initial,
            final: final,
            eSIMInstalled: self.eSIMInstalled,
            cellularDataWorked: self.cellularDataWorked,
            originalVerizonServiceIntact: self.originalVerizonIntact,
            rebootPersistenceConfirmed: self.rebootPersistenceVerified,
            technicianNotes: self.technicianNotes
        )
        self.comparisonResult = comp
        self.currentExperiment?.comparisonResult = comp
        self.currentExperiment?.outcome = comp.classifiedOutcome
        self.currentExperiment?.completionTimestamp = Date()
        self.statusMessage = "Outcome Classified: \(comp.classifiedOutcome.rawValue)"
    }
    
    // MARK: - Control 6: Export Evidence
    public func exportEvidence() throws -> (jsonURL: URL, markdownURL: URL) {
        guard var exp = currentExperiment else {
            throw NSError(domain: "CarrierLab", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active experiment to export."])
        }
        
        exp.completionTimestamp = Date()
        let (jsonURL, mdURL) = try experimentManager.saveExperiment(exp, allowOverwrite: true)
        loadExperimentHistory()
        self.activeStep = .completed
        self.statusMessage = "Experiment dossier exported to \(mdURL.lastPathComponent)."
        return (jsonURL, mdURL)
    }
    
    // MARK: - Screenshot Attachment
    public func attachScreenshot(url: URL, caption: String) {
        guard let exp = currentExperiment else { return }
        do {
            let attachment = try experimentManager.attachScreenshot(
                experimentId: exp.id,
                sourceURL: url,
                caption: caption
            )
            self.currentExperiment?.attachedEvidence.append(attachment)
            self.statusMessage = "Attached screenshot: \(attachment.fileName) (SHA-256: \(attachment.sha256Checksum.prefix(8))...)"
        } catch {
            self.errorMessage = "Failed to attach screenshot: \(error.localizedDescription)"
        }
    }
    
    public func resetExperiment() {
        self.currentBaseline = nil
        self.postTestBaseline = nil
        self.currentExperiment = nil
        self.comparisonResult = nil
        self.eSIMInstalled = false
        self.cellularRegistrationOccurred = false
        self.cellularDataWorked = false
        self.testCallSucceeded = false
        self.originalVerizonIntact = true
        self.rebootPersistenceVerified = false
        self.activeStep = .baselineCapture
        self.statusMessage = "Ready for new experiment."
    }
}
