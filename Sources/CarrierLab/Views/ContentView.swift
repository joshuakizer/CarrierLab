import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

public struct ContentView: View {
    @StateObject private var viewModel: CarrierLabViewModel
    @State private var selectedTab: NavigationItem = .overview
    
    public enum NavigationItem: String, CaseIterable, Identifiable {
        case overview = "Device Overview"
        case carrierLock = "Carrier Lock Verification"
        case logs = "Diagnostic Logs"
        case export = "Export Report"
        case research = "Research & Architecture"
        
        public var id: String { rawValue }
        
        public var iconName: String {
            switch self {
            case .overview: return "iphone.gen3"
            case .carrierLock: return "lock.shield"
            case .logs: return "terminal"
            case .export: return "doc.text"
            case .research: return "books.vertical"
            }
        }
    }
    
    public init(viewModel: CarrierLabViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? CarrierLabViewModel())
    }
    
    public var body: some View {
        NavigationSplitView {
            List(NavigationItem.allCases, selection: $selectedTab) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.iconName)
                }
            }
            .navigationTitle("CarrierLab")
            .listStyle(.sidebar)
            
            // Sidebar Footer Device Status
            VStack(alignment: .leading, spacing: 6) {
                Divider()
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.connectionStatus.isConnected ? Color.green : Color.secondary)
                        .frame(width: 8, height: 8)
                    Text(viewModel.connectionStatus.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        } detail: {
            switch selectedTab {
            case .overview:
                DeviceOverviewView(viewModel: viewModel)
            case .carrierLock:
                CarrierLockVerificationView(viewModel: viewModel)
            case .logs:
                DiagnosticLogView(viewModel: viewModel)
            case .export:
                ExportReportView(viewModel: viewModel)
            case .research:
                ResearchSummaryView()
            }
        }
        .frame(minWidth: 900, minHeight: 620)
    }
}

public struct ResearchSummaryView: View {
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Baseband & Carrier Lock Security Architecture")
                        .font(.system(size: 24, weight: .bold))
                    Text("Comparative analysis of public tools, baseband protocols, and cryptographic lock enforcement.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Card 1: libimobiledevice
                ResearchCard(
                    title: "1. libimobiledevice (Lockdown Protocol)",
                    repoUrl: "github.com/libimobiledevice/libimobiledevice",
                    capability: "Safe, non-invasive query of application processor services via usbmuxd and lockdownd.",
                    status: "Fully Applicable to Phase 1 diagnostics. Retrieves ProductType, ProductVersion, BuildVersion, and BasebandVersion without modifying device state.",
                    color: .blue
                )
                
                // Card 2: BaseTrace
                ResearchCard(
                    title: "2. seemoo-lab/BaseTrace (Baseband IPC Tracing)",
                    repoUrl: "github.com/seemoo-lab/BaseTrace",
                    capability: "Dissects AP-to-Baseband IPC over PCIe/USB. Qualcomm: QMI protocol (libqmi extensions). Intel/Apple: ARI protocol (Apple Remote Invocation).",
                    status: "Applicable for passive cellular protocol sniffing. Active packet injection (qmi-inject) requires root privileges / jailbreak. Does NOT bypass cryptographic carrier lock tickets.",
                    color: .purple
                )
                
                // Card 3: baseband-research
                ResearchCard(
                    title: "3. userlandkernel/baseband-research (Historical Qualcomm 32-bit)",
                    repoUrl: "github.com/userlandkernel/baseband-research",
                    capability: "Explores legacy OKL4 microkernel and AT-command interfaces on 32-bit Qualcomm modems (iPhone 4/4S/5 era).",
                    status: "Obsolete for modern hardware. Modern 64-bit devices enforce hardware secure boot, Baseband TSS cryptographic tickets, and strict memory isolation.",
                    color: .orange
                )
                
                // Core conclusion
                VStack(alignment: .leading, spacing: 8) {
                    Text("Carrier Lock Security Analysis")
                        .font(.headline)
                    Text("""
                    Carrier Lock on iOS is not a local flag stored in mutable baseband NVRAM or EEPROM.
                    It is an end-to-end cryptographic enforcement system:
                    1. Device connects to Apple Activation Servers during setup, provisioning, or SIM swap.
                    2. Apple Activation Servers verify IMEI/MEID against carrier databases (GSX).
                    3. Apple signs an Activation Record (WildcardTicket) containing the permitted carrier MCC/MNC policy.
                    4. The baseband processor verifies the Apple cryptographic signature against its immutable Boot ROM public key.
                    5. Circumventing this enforcement without Apple's signature requires breaking RSA/ECDSA cryptography or exploiting a baseband boot ROM vulnerability.
                    """)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            }
            .padding(24)
        }
    }
}

private struct ResearchCard: View {
    let title: String
    let repoUrl: String
    let capability: String
    let status: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
                Text(repoUrl)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("**Documented Capability:** \(capability)")
                .font(.subheadline)
            Text("**Engineering Assessment:** \(status)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(color.opacity(0.06))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1))
    }
}
