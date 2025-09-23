//
//  ExportView.swift
//  Export and MIDI integration UI
//

import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @ObservedObject var exportManager: ExportManager
    @ObservedObject var midiManager: MIDIOutputManager
    @ObservedObject var analysisEngine: RealTimeAnalysisEngine
    
    @State private var selectedFormat: ExportManager.ExportFormat = .json
    @State private var showingExportPicker = false
    @State private var showingMIDISettings = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("Export & MIDI")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Export results and connect to DAWs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Export Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Export Analysis Results")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                // Format Selection
                HStack {
                    Text("Format:")
                        .frame(width: 60, alignment: .leading)
                    
                    Picker("Export Format", selection: $selectedFormat) {
                        ForEach(ExportManager.ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 120)
                    
                    Text(selectedFormat.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Export Button
                HStack {
                    Button(action: { showingExportPicker = true }) {
                        HStack {
                            if exportManager.isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            
                            Text(exportManager.isExporting ? "Exporting..." : "Export Results")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(analysisEngine.analysisHistory.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(analysisEngine.analysisHistory.isEmpty ? .secondary : .white)
                        .cornerRadius(8)
                    }
                    .disabled(analysisEngine.analysisHistory.isEmpty || exportManager.isExporting)
                    
                    Text("\(analysisEngine.analysisHistory.count) results")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
                
                // Export Progress
                if exportManager.isExporting {
                    ProgressView(value: exportManager.exportProgress) {
                        Text("Exporting... \(Int(exportManager.exportProgress * 100))%")
                            .font(.caption)
                    }
                }
                
                // Last Export Info
                if let lastExport = exportManager.lastExportURL {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text("Last export: \(lastExport.lastPathComponent)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Show in Finder") {
                            NSWorkspace.shared.selectFile(lastExport.path, inFileViewerRootedAtPath: "")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)
            
            Divider()
            
            // MIDI Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("MIDI Output")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Toggle("", isOn: $midiManager.isEnabled)
                        .toggleStyle(SwitchToggleStyle())
                        .disabled(!midiManager.isEnabled)
                }
                
                if midiManager.isEnabled {
                    // MIDI Port Selection
                    HStack {
                        Text("Port:")
                            .frame(width: 60, alignment: .leading)
                        
                        Picker("MIDI Port", selection: $midiManager.selectedPort) {
                            ForEach(midiManager.availablePorts) { port in
                                HStack {
                                    Text(port.name)
                                    if port.isVirtual {
                                        Image(systemName: "circle.dashed")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .tag(port as MIDIPortInfo?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onAppear {
                            midiManager.scanForPorts()
                        }
                        
                        Button("Scan") {
                            midiManager.scanForPorts()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    
                    // MIDI Status
                    if let selectedPort = midiManager.selectedPort {
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            
                            Text("Connected to: \(selectedPort.name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !midiManager.lastSentMessage.isEmpty {
                            Text("Last sent: \(midiManager.lastSentMessage)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    // MIDI Settings Button
                    Button(action: { showingMIDISettings = true }) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("MIDI Settings")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)
            
            Spacer()
        }
        .sheet(isPresented: $showingExportPicker) {
            ExportFilePicker(
                format: selectedFormat,
                onFileSelected: { url in
                    exportManager.exportAnalysisResults(
                        analysisEngine.analysisHistory,
                        format: selectedFormat,
                        to: url
                    )
                }
            )
        }
        .sheet(isPresented: $showingMIDISettings) {
            MIDISettingsView(midiManager: midiManager)
        }
        .onReceive(analysisEngine.$currentResult) { result in
            if let result = result, midiManager.isEnabled {
                midiManager.sendAnalysisUpdate(result)
            }
        }
    }
}

// MARK: - Export File Picker

struct ExportFilePicker: View {
    let format: ExportManager.ExportFormat
    let onFileSelected: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Export Analysis Results")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Choose location to save \(format.rawValue) file")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Choose Location") {
                let savePanel = NSSavePanel()
                savePanel.title = "Export Analysis Results"
                savePanel.nameFieldStringValue = "music_analysis.\(format.fileExtension)"
                savePanel.allowedContentTypes = [UTType(filenameExtension: format.fileExtension) ?? .data]
                
                savePanel.begin { response in
                    if response == .OK, let url = savePanel.url {
                        onFileSelected(url)
                        dismiss()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            
            Text("Supported formats:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(ExportManager.ExportFormat.allCases, id: \.self) { exportFormat in
                    HStack {
                        Text("• \(exportFormat.rawValue)")
                            .fontWeight(exportFormat == format ? .semibold : .regular)
                        Text("- \(exportFormat.description)")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

// MARK: - MIDI Settings View

struct MIDISettingsView: View {
    @ObservedObject var midiManager: MIDIOutputManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var sendBPM = true
    @State private var sendChords = true
    @State private var sendKey = true
    @State private var sendConfidence = true
    @State private var selectedDAW: DAWType = .logicPro
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // MIDI Output Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("MIDI Output Settings")
                        .font(.headline)
                    
                    Toggle("Send BPM as MIDI Clock", isOn: $sendBPM)
                    Toggle("Send Chords as Notes", isOn: $sendChords)
                    Toggle("Send Key Changes", isOn: $sendKey)
                    Toggle("Send Confidence as CC", isOn: $sendConfidence)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
                
                // DAW Integration
                VStack(alignment: .leading, spacing: 12) {
                    Text("DAW Integration")
                        .font(.headline)
                    
                    Picker("Target DAW", selection: $selectedDAW) {
                        Text("Logic Pro").tag(DAWType.logicPro)
                        Text("Ableton Live").tag(DAWType.ableton)
                        Text("Pro Tools").tag(DAWType.proTools)
                        Text("Cubase").tag(DAWType.cubase)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text("Optimizes MIDI output for your DAW")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
                
                // Available Ports
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available MIDI Ports")
                        .font(.headline)
                    
                    if midiManager.availablePorts.isEmpty {
                        Text("No MIDI ports found")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(midiManager.availablePorts) { port in
                            HStack {
                                Image(systemName: port.isVirtual ? "circle.dashed" : "circle.fill")
                                    .foregroundColor(port == midiManager.selectedPort ? .blue : .secondary)
                                
                                Text(port.name)
                                    .font(.subheadline)
                                
                                if port.isVirtual {
                                    Text("Virtual")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                Spacer()
                                
                                if port == midiManager.selectedPort {
                                    Text("Selected")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    
                    Button("Refresh Ports") {
                        midiManager.scanForPorts()
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("MIDI Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        // Apply settings
                        midiManager.setupForDAW(selectedDAW)
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - Quick Export Buttons

struct QuickExportButtons: View {
    @ObservedObject var exportManager: ExportManager
    @ObservedObject var analysisEngine: RealTimeAnalysisEngine
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach([ExportManager.ExportFormat.json, .csv, .midi], id: \.self) { format in
                Button(action: {
                    quickExport(format: format)
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: iconForFormat(format))
                            .font(.caption)
                        Text(format.rawValue)
                            .font(.caption2)
                    }
                    .frame(width: 50, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
                .disabled(analysisEngine.analysisHistory.isEmpty)
            }
        }
    }
    
    private func quickExport(format: ExportManager.ExportFormat) {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "music_analysis.\(format.fileExtension)"
        savePanel.allowedContentTypes = [UTType(filenameExtension: format.fileExtension) ?? .data]
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                exportManager.exportAnalysisResults(
                    analysisEngine.analysisHistory,
                    format: format,
                    to: url
                )
            }
        }
    }
    
    private func iconForFormat(_ format: ExportManager.ExportFormat) -> String {
        switch format {
        case .json: return "doc.text"
        case .csv: return "tablecells"
        case .midi: return "music.note"
        case .xml: return "doc.text"
        case .txt: return "doc.plaintext"
        }
    }
}