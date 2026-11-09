import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

public struct DiagnosticLogView: View {
    @ObservedObject var viewModel: CarrierLabViewModel
    @State private var filterLevel: LogFilter = .all
    @State private var searchText: String = ""
    
    public enum LogFilter: String, CaseIterable {
        case all = "All"
        case info = "Info"
        case warning = "Warnings"
        case error = "Errors"
        case success = "Success"
    }
    
    public init(viewModel: CarrierLabViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Diagnostic Console")
                        .font(.system(size: 24, weight: .bold))
                    Text("Sanitized device event trace and lockdown protocol logs.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Picker("Filter", selection: $filterLevel) {
                    ForEach(LogFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
            
            // Privacy assurance pill
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.blue)
                Text("Operational Privacy Active: Hardware UDIDs, IMEIs, and Serials are automatically masked in this stream.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(6)
            
            // Console Output Window
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if filteredLogs.isEmpty {
                            Text("No diagnostic logs recorded yet.")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(12)
                        } else {
                            ForEach(filteredLogs) { log in
                                LogRow(entry: log)
                                    .id(log.id)
                            }
                        }
                    }
                    .padding(12)
                }
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(24)
    }
    
    private var filteredLogs: [LogEntry] {
        viewModel.diagnosticLogs.filter { entry in
            switch filterLevel {
            case .all: return true
            case .info: return entry.level == .info
            case .warning: return entry.level == .warning
            case .error: return entry.level == .error
            case .success: return entry.level == .success
            }
        }
    }
}

private struct LogRow: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            
            Text("[\(entry.level.rawValue)]")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(levelColor)
                .frame(width: 60, alignment: .leading)
            
            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
    
    private var levelColor: Color {
        switch entry.level {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
}
