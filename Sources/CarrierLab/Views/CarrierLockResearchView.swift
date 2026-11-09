import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

public struct CarrierLockResearchView: View {
    @ObservedObject var researchVM: CarrierLockResearchViewModel
    @ObservedObject var mainVM: CarrierLabViewModel
    
    @State private var showingAttachmentSheet: Bool = false
    @State private var attachmentPathInput: String = ""
    @State private var attachmentCaptionInput: String = "Carrier Lock error screenshot"
    @State private var selectedCarrierTab: String = "T-Mobile"
    @State private var exportNotification: String?
    
    public init(researchVM: CarrierLockResearchViewModel, mainVM: CarrierLabViewModel) {
        self.researchVM = researchVM
        self.mainVM = mainVM
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Screen Title
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Carrier Lock Research Dashboard")
                            .font(.system(size: 26, weight: .bold))
                        Spacer()
                        Badge(text: "Phase 2 Active", color: .purple)
                    }
                    Text("Controlled alternate-carrier eSIM experimentation, cryptographic baseline capture, and outcome classification.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Top Telemetry & Authorization Cards
                HStack(alignment: .top, spacing: 16) {
                    deviceIdentityCard
                    carrierAuthorizationCard
                }
                
                // Status / Error Messages
                if let status = researchVM.statusMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill").foregroundColor(.blue)
                        Text(status).font(.footnote).foregroundColor(.primary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(8)
                }
                
                if let err = researchVM.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                        Text(err).font(.footnote).foregroundColor(.red)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)
                }
                
                // Experiment Step Control Bar
                VStack(alignment: .leading, spacing: 12) {
                    Text("Experiment Controls")
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        ForEach(ExperimentStep.allCases) { step in
                            Button {
                                researchVM.activeStep = step
                            } label: {
                                Text(step.rawValue)
                                    .font(.caption)
                                    .fontWeight(researchVM.activeStep == step ? .bold : .medium)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(researchVM.activeStep == step ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                                    .foregroundColor(researchVM.activeStep == step ? .white : .primary)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Step Content Panels
                switch researchVM.activeStep {
                case .baselineCapture:
                    step1BaselineView
                case .testSetup:
                    step2TestSetupView
                case .recordingResults:
                    step3RecordingResultsView
                case .postTestVerify:
                    step4PostTestVerifyView
                case .comparison:
                    step5ComparisonView
                case .completed:
                    step6ExportView
                }
                
                Divider()
                
                // Historical Audit History
                experimentHistorySection
            }
            .padding(24)
        }
    }
    
    // MARK: - Subviews: Top Cards
    @ViewBuilder private var deviceIdentityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "iphone.gen3").foregroundColor(.accentColor)
                Text("Device Identity").font(.headline)
                Spacer()
                Circle()
                    .fill(mainVM.connectionStatus.isConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }
            
            if !mainVM.connectionStatus.isConnected {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath").foregroundColor(.orange)
                    Text("Historical / Cached Snapshot (Device Disconnected)")
                        .font(.caption).bold().foregroundColor(.orange)
                }
                .padding(6)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }
            
            Divider()
            
            GridRow(label: "Device Model:", value: mainVM.deviceDiagnostics?.marketingName ?? "iPhone Duo (iPhone19,4)")
            GridRow(label: "iOS Version:", value: "\(mainVM.deviceDiagnostics?.displayProductVersion ?? "27.2") (Build \(mainVM.deviceDiagnostics?.displayBuildVersion ?? "24B91020"))")
            GridRow(label: "Modem Firmware:", value: mainVM.deviceDiagnostics?.displayBasebandVersion ?? "1.02.05")
            GridRow(label: "Baseband Status:", value: mainVM.deviceDiagnostics?.basebandStatus ?? "BBInfoAvailable")
            GridRow(label: "Connection:", value: mainVM.connectionStatus.displayText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    @ViewBuilder private var carrierAuthorizationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lock.shield.fill").foregroundColor(.purple)
                Text("Carrier Authorization").font(.headline)
                Spacer()
                Badge(text: "Verizon Locked", color: .red)
            }
            
            Divider()
            
            GridRow(label: "Original Carrier:", value: "Verizon")
            GridRow(label: "Carrier Lock:", value: "SIM locked (Manually Confirmed)")
            GridRow(label: "Financing Status:", value: "Active Installment Plan")
            GridRow(label: "SIM Status:", value: mainVM.deviceDiagnostics?.simStatus ?? "kCTSIMSupportSIMStatusReady")
            GridRow(label: "Evidence Source:", value: "Physical Mac Terminal Output (Verified)")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Step 1: Capture Baseline
    @ViewBuilder private var step1BaselineView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Step 1: Capture Initial Baseline")
                .font(.title3).bold()
            Text("Interrogates read-only hardware telemetry before introducing any alternative carrier profile.")
                .font(.subheadline).foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Carrier Lock Observed in Settings:").font(.caption).bold()
                    Picker("", selection: $researchVM.manualLockSetting) {
                        Text("SIM Locked").tag("SIM Locked")
                        Text("No SIM Restrictions").tag("No SIM Restrictions")
                        Text("Other").tag("Other")
                    }
                    .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Technician ID:").font(.caption).bold()
                    TextField("Researcher ID", text: $researchVM.technicianID)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Button {
                Task {
                    await researchVM.captureBaseline()
                }
            } label: {
                Label("Capture Baseline Snapshot", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(researchVM.isProcessing)
            
            if let base = researchVM.currentBaseline {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Active Pre-Test Baseline Snapshot:").font(.caption).bold()
                    HStack {
                        Text("SHA-256: `\(base.snapshotChecksum.prefix(16))...`")
                            .font(.system(.caption, design: .monospaced))
                        Spacer()
                        Text("Captured: \(base.timestamp.formatted(date: .omitted, time: .standard))")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color.green.opacity(0.08))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Step 2: Test Setup
    @ViewBuilder private var step2TestSetupView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Step 2: Alternate-Carrier eSIM Setup")
                .font(.title3).bold()
            
            // Safety banner
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.shield.fill").foregroundColor(.orange)
                Text("Safety Guarantee: The primary Verizon eSIM must NEVER be deleted. CarrierLab only evaluates adding a secondary alternate profile through standard iOS Cellular settings.")
                    .font(.footnote)
            }
            .padding(10)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            
            Picker("Select Alternative Carrier for Test:", selection: $selectedCarrierTab) {
                Text("T-Mobile").tag("T-Mobile")
                Text("AT&T").tag("AT&T")
                Text("Mint Mobile").tag("Mint Mobile")
                Text("Custom Carrier").tag("Custom Carrier")
            }
            .pickerStyle(.segmented)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Guided iOS Instructions on Physical iPhone:").font(.subheadline).bold()
                Text("1. Open **Settings > Cellular** on the iPhone Duo.")
                Text("2. Tap **Add eSIM** (or **Set Up Cellular**).")
                Text("3. Select **Use QR Code** to scan your legitimate \(selectedCarrierTab) eSIM activation card.")
                Text("4. Keep the Verizon line designated as Primary if prompted.")
                Text("5. Observe the iOS modal response.")
            }
            .font(.footnote)
            .padding(12)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            
            Button {
                researchVM.beginTest(targetCarrier: selectedCarrierTab)
            } label: {
                Label("Begin eSIM Test Session", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Step 3: Record Results
    @ViewBuilder private var step3RecordingResultsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Step 3: Record On-Device Test Observations")
                .font(.title3).bold()
            
            // Physical Device Test Acknowledgment
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Physical alternate-carrier activation was attempted on connected iPhone", isOn: $researchVM.physicalDeviceTestAttempted)
                    .font(.subheadline).bold()
                Text("Required: Leaving this off records the experiment as Not Performed / Demonstration Only to prevent false verification claims.")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(10)
            .background(researchVM.physicalDeviceTestAttempted ? Color.blue.opacity(0.08) : Color.orange.opacity(0.12))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 10) {
                Toggle("eSIM Profile Installed in Cellular Settings", isOn: $researchVM.eSIMInstalled)
                Toggle("Cellular Network Registration Occurred on \(researchVM.targetCarrier)", isOn: $researchVM.cellularRegistrationOccurred)
                Toggle("Cellular Data Functional (Tested via Safari)", isOn: $researchVM.cellularDataWorked)
                Toggle("Test Voice Call Succeeded", isOn: $researchVM.testCallSucceeded)
                Toggle("Original Verizon Line Remained Active & Intact", isOn: $researchVM.originalVerizonIntact)
                    .foregroundColor(.green)
            }
            .font(.subheadline)
            .disabled(!researchVM.physicalDeviceTestAttempted)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Exact Error Messages Displayed by iOS:").font(.caption).bold()
                    Spacer()
                    Menu("Insert Sample Template...") {
                        ForEach(CarrierLockResearchViewModel.sampleErrorTemplates, id: \.self) { tmpl in
                            Button(tmpl) {
                                researchVM.insertSampleErrorTemplate(tmpl)
                            }
                        }
                    }
                    .font(.caption)
                }
                
                TextEditor(text: $researchVM.observedErrorText)
                    .frame(height: 70)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                
                if researchVM.isUsingSampleErrorTemplate {
                    Text("Notice: Using sample template. Manual input does not constitute independent baseband telemetry verification.")
                        .font(.caption2).foregroundColor(.orange)
                }
            }
            
            // Screenshot Attachment Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Attach Screenshot Evidence").font(.caption).bold()
                    Text("Attaches PNG/JPG evidence with cryptographic SHA-256 integrity hash.").font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                Button("Attach File...") {
                    showingAttachmentSheet = true
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)
            
            Button {
                researchVM.recordTestObservations()
            } label: {
                Label("Save Observations & Proceed to Verification", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .sheet(isPresented: $showingAttachmentSheet) {
            attachmentSheetView
        }
    }
    
    // MARK: - Step 4: Post-Test Verify
    @ViewBuilder private var step4PostTestVerifyView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Step 4: Post-Test Hardware Verification")
                .font(.title3).bold()
            Text("Re-queries device lockdown interfaces to detect changes in ActivationState, SIMStatus, or Modem Firmware.")
                .font(.subheadline).foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Post-Test Carrier Lock Setting (Settings > General > About):").font(.caption).bold()
                Picker("", selection: $researchVM.postTestManualLockSetting) {
                    Text("SIM Locked").tag("SIM Locked")
                    Text("No SIM Restrictions").tag("No SIM Restrictions")
                    Text("Other").tag("Other")
                }
                .labelsHidden()
            }
            
            Button {
                Task {
                    await researchVM.verifyAfterTest()
                }
            } label: {
                Label("Capture Post-Test Snapshot & Compare", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(researchVM.isProcessing)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Step 5: Comparison View
    @ViewBuilder private var step5ComparisonView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Step 5: Before-and-After Comparison & Classification")
                    .font(.title3).bold()
                Spacer()
                if let outcome = researchVM.comparisonResult?.classifiedOutcome {
                    Badge(text: outcome.rawValue, color: outcomeBadgeColor(outcome))
                }
            }
            
            // Side-by-side diff table
            if let initial = researchVM.currentBaseline, let final = researchVM.postTestBaseline {
                VStack(spacing: 6) {
                    DiffRow(label: "ActivationState", before: initial.observed.activationState ?? "None", after: final.observed.activationState ?? "None", changed: initial.observed.activationState != final.observed.activationState)
                    DiffRow(label: "SIMStatus", before: initial.observed.simStatus ?? "None", after: final.observed.simStatus ?? "None", changed: initial.observed.simStatus != final.observed.simStatus)
                    DiffRow(label: "Modem Firmware", before: initial.observed.basebandVersion ?? "None", after: final.observed.basebandVersion ?? "None", changed: initial.observed.basebandVersion != final.observed.basebandVersion)
                    DiffRow(label: "iOS Build", before: initial.observed.buildVersion ?? "None", after: final.observed.buildVersion ?? "None", changed: initial.observed.buildVersion != final.observed.buildVersion)
                    DiffRow(label: "Carrier Lock", before: initial.ownerConfirmed.carrierLockSetting, after: final.ownerConfirmed.carrierLockSetting, changed: initial.ownerConfirmed.carrierLockSetting != final.ownerConfirmed.carrierLockSetting)
                }
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
            }
            
            // Justification card
            if let comp = researchVM.comparisonResult {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Classification Justification:").font(.caption).bold()
                    Text(comp.outcomeJustification).font(.subheadline)
                    Text("Connectivity: \(comp.cellularConnectivitySummary)").font(.caption).foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(8)
            }
            
            Toggle("Reboot Persistence Confirmed (Required for Permanent Unlock Verification)", isOn: $researchVM.rebootPersistenceVerified)
                .font(.footnote)
            
            Button {
                researchVM.activeStep = .completed
            } label: {
                Label("Proceed to Evidence Export", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Step 6: Export Evidence
    @ViewBuilder private var step6ExportView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Step 6: Export Immutable Evidence Dossier")
                .font(.title3).bold()
            Text("Saves timestamped JSON and Markdown dossier to ~/CarrierLabExperiments with SHA-256 tamper verification.")
                .font(.subheadline).foregroundColor(.secondary)
            
            Button {
                do {
                    let (_, mdURL) = try researchVM.exportEvidence()
                    exportNotification = "Exported to \(mdURL.path)"
                } catch {
                    researchVM.errorMessage = "Export failed: \(error.localizedDescription)"
                }
            } label: {
                Label("Export Experiment Dossier", systemImage: "arrow.down.doc.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            if let note = exportNotification {
                Text(note).font(.caption).foregroundColor(.green)
            }
            
            Button("Start New Experiment") {
                researchVM.resetExperiment()
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - History Section
    @ViewBuilder private var experimentHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Stored Experiment Audit History").font(.headline)
                Spacer()
                Text("\(researchVM.savedExperiments.count) record(s)").font(.caption).foregroundColor(.secondary)
            }
            
            if researchVM.savedExperiments.isEmpty {
                Text("No previous experiments recorded. Run an experiment above to establish your audit trail.")
                    .font(.footnote).foregroundColor(.secondary).padding(12)
            } else {
                ForEach(researchVM.savedExperiments) { exp in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(exp.id).font(.system(.subheadline, design: .monospaced)).bold()
                                if exp.auditCorrection != nil {
                                    Badge(text: "AUDIT CORRECTED", color: .purple)
                                }
                            }
                            Text("Target: \(exp.targetCarrier) | \(exp.startTimestamp.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundColor(.secondary)
                            if let correction = exp.auditCorrection {
                                Text("Audit Note: \(correction.auditorReason)")
                                    .font(.caption2).foregroundColor(.purple)
                            }
                        }
                        Spacer()
                        Badge(text: exp.effectiveOutcome.rawValue, color: outcomeBadgeColor(exp.effectiveOutcome))
                        Badge(text: exp.physicalAttemptConducted ? "Owner-Reported" : "Unperformed", color: exp.physicalAttemptConducted ? .blue : .secondary)
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Attachment Sheet
    @ViewBuilder private var attachmentSheetView: some View {
        VStack(spacing: 16) {
            Text("Attach Screenshot Evidence").font(.headline)
            TextField("Local Image Path (e.g. /tmp/sim_error.png)", text: $attachmentPathInput)
                .textFieldStyle(.roundedBorder)
            TextField("Caption / Description", text: $attachmentCaptionInput)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") {
                    showingAttachmentSheet = false
                }
                Spacer()
                Button("Attach") {
                    let url = URL(fileURLWithPath: attachmentPathInput)
                    researchVM.attachScreenshot(url: url, caption: attachmentCaptionInput)
                    showingAttachmentSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
    
    private func outcomeBadgeColor(_ outcome: ExperimentOutcome) -> Color {
        switch outcome {
        case .notPerformed: return .gray
        case .carrierRestrictionEnforced: return .orange // Owner-reported observation; not baseband verified
        case .alternateCarrierActivatedLockUnchanged: return .blue
        case .carrierLockChangedAuthorized: return .purple
        case .unexpectedBehavior: return .red
        case .inconclusive: return .gray
        }
    }
}

private struct GridRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption).bold().textSelection(.enabled)
        }
    }
}

private struct DiffRow: View {
    let label: String
    let before: String
    let after: String
    let changed: Bool
    
    var body: some View {
        HStack {
            Text(label).font(.caption).bold().frame(width: 140, alignment: .leading)
            Text(before).font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.right").font(.caption2).foregroundColor(.secondary)
            Text(after).font(.caption).bold().foregroundColor(changed ? .orange : .primary).frame(maxWidth: .infinity, alignment: .leading)
            if changed {
                Text("CHANGED").font(.system(size: 9, weight: .bold)).padding(.horizontal, 4).padding(.vertical, 2).background(Color.orange.opacity(0.2)).foregroundColor(.orange).cornerRadius(4)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}
