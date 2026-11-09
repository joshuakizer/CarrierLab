import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

public struct ExportReportView: View {
    @ObservedObject var viewModel: CarrierLabViewModel
    @State private var exportSuccessMessage: String?
    @State private var markdownPreview: String = ""
    @State private var isShowingShare: Bool = false
    
    public init(viewModel: CarrierLabViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Diagnostic Report Export")
                            .font(.system(size: 24, weight: .bold))
                        Text("Generate and persist timestamped JSON and Markdown reports with full privacy sanitization.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button {
                        doSaveReport()
                    } label: {
                        Label("Save Diagnostic Report", systemImage: "arrow.down.doc.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                Divider()
                
                // Export confirmation banner
                if let message = exportSuccessMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Report Successfully Generated & Saved")
                                .font(.headline)
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Saved Locations
                if let paths = viewModel.lastExportPaths {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Saved Local Artifacts")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                Text("Markdown Report:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(paths.markdown)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                            Divider()
                            HStack {
                                Image(systemName: "curlybraces")
                                    .foregroundColor(.purple)
                                Text("JSON Raw Telemetry:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(paths.json)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(14)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                    }
                }
                
                // Markdown Live Preview
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Report Preview")
                            .font(.headline)
                        Spacer()
                        Button {
                            updatePreview()
                        } label: {
                            Label("Refresh Preview", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                    }
                    
                    ScrollView {
                        Text(markdownPreview.isEmpty ? generatePreviewText() : markdownPreview)
                            .font(.system(.body, design: .monospaced))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: 320)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                }
            }
            .padding(24)
        }
        .onAppear {
            updatePreview()
        }
    }
    
    private func updatePreview() {
        markdownPreview = generatePreviewText()
    }
    
    private func generatePreviewText() -> String {
        let report = DiagnosticReport(
            hostEnvironment: viewModel.hostEnvironment,
            connectionStatus: viewModel.connectionStatus.displayText,
            deviceDiagnostics: viewModel.deviceDiagnostics,
            manualTechnicianConfirmation: viewModel.carrierLockConfirmation,
            rawDiagnosticsErrors: viewModel.rawErrors,
            citedResearchNotes: "Carrier lock is cryptographically verified via Apple activation tickets."
        )
        return report.formattedMarkdown()
    }
    
    private func doSaveReport() {
        do {
            let (jsonURL, mdURL) = try viewModel.saveDiagnosticReport()
            exportSuccessMessage = "Saved to \(mdURL.lastPathComponent) and \(jsonURL.lastPathComponent)"
            updatePreview()
        } catch {
            exportSuccessMessage = "Error saving report: \(error.localizedDescription)"
        }
    }
}
