import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

public struct CarrierLockVerificationView: View {
    @ObservedObject var viewModel: CarrierLabViewModel
    
    @State private var selectedLockState: CarrierLockConfirmation.LockState = .simLocked
    @State private var carrierName: String = "Verizon"
    @State private var financingStatus: CarrierLockConfirmation.FinancingStatus = .financedActive
    @State private var technicianID: String = "Researcher-01"
    @State private var notes: String = "Physical device inspection on bench. Device reports SIM locked to Verizon under active device payment plan."
    @State private var showConfirmationAlert: Bool = false
    
    public init(viewModel: CarrierLabViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Carrier Lock Verification")
                        .font(.system(size: 24, weight: .bold))
                    Text("Manual visual confirmation of Carrier Lock enforcement from physical device Settings.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Instructions banner
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 24))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Standard Verification Protocol")
                            .font(.headline)
                        Text("On the physical device, navigate to: Settings > General > About > Carrier Lock. Verify whether iOS displays 'SIM locked' or 'No SIM restrictions'. Compare this with lockdownd's reported SIMStatus and GSX activation records.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(10)
                
                // Active Confirmation Status Banner
                if viewModel.carrierLockConfirmation.isConfirmed {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Manual Status: \(viewModel.carrierLockConfirmation.confirmedState.rawValue)")
                                .font(.headline)
                            if let date = viewModel.carrierLockConfirmation.verificationDate {
                                Text("Confirmed by \(viewModel.carrierLockConfirmation.technicianID) at \(date.formatted(date: .abbreviated, time: .standard))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Form
                VStack(alignment: .leading, spacing: 16) {
                    Text("Record Physical Inspection")
                        .font(.headline)
                    
                    Picker("Reported Lock State:", selection: $selectedLockState) {
                        ForEach(CarrierLockConfirmation.LockState.allCases, id: \.self) { state in
                            Text(state.rawValue).tag(state)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Carrier Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("e.g. Verizon", text: $carrierName)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Financing / Subsidy Status")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Picker("", selection: $financingStatus) {
                                ForEach(CarrierLockConfirmation.FinancingStatus.allCases, id: \.self) { status in
                                    Text(status.rawValue).tag(status)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Technician ID / Researcher Handle")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("e.g. Researcher-01", text: $technicianID)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Inspection & Baseband Audit Notes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextEditor(text: $notes)
                            .font(.body)
                            .frame(height: 80)
                            .padding(4)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                    }
                    
                    Button {
                        viewModel.confirmCarrierLock(
                            state: selectedLockState,
                            carrierName: carrierName,
                            financing: financingStatus,
                            technician: technicianID,
                            notes: notes
                        )
                        showConfirmationAlert = true
                    } label: {
                        Label("Save Manual Confirmation", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(20)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding(24)
        }
        .alert("Confirmation Recorded", isPresented: $showConfirmationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Carrier Lock status '\(selectedLockState.rawValue)' has been timestamped and recorded in the audit trail.")
        }
    }
}
