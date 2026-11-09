import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

public struct DeviceOverviewView: View {
    @ObservedObject var viewModel: CarrierLabViewModel
    
    public init(viewModel: CarrierLabViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header & Connection Status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Device Overview")
                            .font(.system(size: 24, weight: .bold))
                        Text("Real-time physical device interface and hardware diagnostic telemetry.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    // Connection Status Badge
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                        Text(viewModel.connectionStatus.displayText)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.12))
                    .cornerRadius(8)
                    
                    Button {
                        Task {
                            await viewModel.runDiagnostics()
                        }
                    } label: {
                        Label(viewModel.isScanning ? "Scanning..." : "Run Diagnostics", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(viewModel.isScanning)
                    .buttonStyle(.borderedProminent)
                }
                
                Divider()
                
                // Telemetry Cards Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    // Card 1: Hardware Model
                    MetricCard(
                        title: "Hardware Model",
                        primaryValue: viewModel.deviceDiagnostics?.displayProductType ?? "Disconnected",
                        secondaryValue: viewModel.deviceDiagnostics?.marketingName ?? "No device attached",
                        systemIcon: "iphone"
                    )
                    
                    // Card 2: iOS Build
                    MetricCard(
                        title: "iOS Version & Build",
                        primaryValue: viewModel.deviceDiagnostics?.displayProductVersion ?? "Unavailable",
                        secondaryValue: "Build: \(viewModel.deviceDiagnostics?.displayBuildVersion ?? "Unavailable")",
                        systemIcon: "gearshape.2"
                    )
                    
                    // Card 3: Modem Firmware (Baseband)
                    MetricCard(
                        title: "Modem Firmware",
                        primaryValue: viewModel.deviceDiagnostics?.displayBasebandVersion ?? "Unavailable",
                        secondaryValue: "Status: \(viewModel.deviceDiagnostics?.basebandStatus ?? "Unavailable")",
                        systemIcon: "antenna.radiowaves.left.and.right"
                    )
                    
                    // Card 4: Activation State
                    MetricCard(
                        title: "Activation State",
                        primaryValue: viewModel.deviceDiagnostics?.activationState ?? "Unavailable",
                        secondaryValue: "SIM: \(viewModel.deviceDiagnostics?.simStatus ?? "Unavailable")",
                        systemIcon: "lock.shield"
                    )
                }
                
                // Privacy Sanitized Identifiers Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "eye.slash.fill")
                            .foregroundColor(.blue)
                        Text("Privacy-Preserving Identifiers (Redacted)")
                            .font(.headline)
                    }
                    
                    VStack(spacing: 8) {
                        SanitizedIdentifierRow(
                            label: "Sanitized UDID",
                            value: viewModel.deviceDiagnostics?.sanitizedUDID ?? "Unavailable / Masked",
                            info: "Masked for operational security; never exposed in public logs."
                        )
                        Divider()
                        SanitizedIdentifierRow(
                            label: "Sanitized Serial",
                            value: viewModel.deviceDiagnostics?.sanitizedSerialNumber ?? "Unavailable / Masked",
                            info: "Masked serial suffix."
                        )
                        Divider()
                        SanitizedIdentifierRow(
                            label: "Sanitized IMEI",
                            value: viewModel.deviceDiagnostics?.sanitizedIMEI ?? "Unavailable / Masked",
                            info: "Baseband modem identifier masked to last 4 digits."
                        )
                    }
                    .padding(14)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }
                
                // Host Environment Metadata
                VStack(alignment: .leading, spacing: 10) {
                    Text("Host Workstation Environment")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        Label(viewModel.hostEnvironment.osName + " " + viewModel.hostEnvironment.osVersion, systemImage: "desktopcomputer")
                        Label(viewModel.hostEnvironment.cpuArchitecture, systemImage: "cpu")
                        Label(viewModel.hostEnvironment.developerTools, systemImage: "hammer")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(10)
            }
            .padding(24)
        }
    }
    
    private var statusColor: Color {
        switch viewModel.connectionStatus {
        case .connected: return .green
        case .connecting: return .orange
        case .error: return .red
        case .disconnected: return .gray
        }
    }
}

private struct MetricCard: View {
    let title: String
    let primaryValue: String
    let secondaryValue: String
    let systemIcon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: systemIcon)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14))
            }
            
            Text(primaryValue)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .lineLimit(1)
            
            Text(secondaryValue)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

private struct SanitizedIdentifierRow: View {
    let label: String
    let value: String
    let info: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(info)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
}
