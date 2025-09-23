//
//  SettingsView.swift
//  Settings and configuration for the music analyzer
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @ObservedObject var inputManager: AudioInputManager
    @ObservedObject var analysisEngine: RealTimeAnalysisEngine
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSampleRate: Double = 44100
    @State private var analysisInterval: Double = 2.0
    @State private var confidenceThreshold: Double = 0.5
    @State private var enableChordDetection = true
    @State private var maxAnalysisTime: Double = 10.0
    @State private var smoothingWindow: Int = 5
    
    private let sampleRates: [Double] = [22050, 44100, 48000, 96000]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Audio Input") {
                    HStack {
                        Text("Current Source:")
                        Spacer()
                        Text(inputManager.getInputSourceDescription())
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Supported Formats:")
                        Spacer()
                        Text(inputManager.getSupportedFormats().joined(separator: ", "))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Sample Rate:")
                        Spacer()
                        Picker("Sample Rate", selection: $selectedSampleRate) {
                            ForEach(sampleRates, id: \.self) { rate in
                                Text("\(Int(rate)) Hz")
                                    .tag(rate)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 120)
                    }
                }
                
                Section("Analysis Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Analysis Interval:")
                            Spacer()
                            Text("\(String(format: "%.1f", analysisInterval))s")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $analysisInterval, in: 1.0...5.0, step: 0.5) {
                            Text("Analysis Interval")
                        }
                        
                        Text("How often to perform analysis. Lower values = more frequent updates but higher CPU usage.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max Analysis Time:")
                            Spacer()
                            Text("\(String(format: "%.0f", maxAnalysisTime))s")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $maxAnalysisTime, in: 5.0...30.0, step: 1.0) {
                            Text("Max Analysis Time")
                        }
                        
                        Text("Maximum audio buffer length for analysis. Longer = more accurate but slower.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Confidence Threshold:")
                            Spacer()
                            Text("\(String(format: "%.1f%%", confidenceThreshold * 100))")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $confidenceThreshold, in: 0.1...0.9, step: 0.1) {
                            Text("Confidence Threshold")
                        }
                        
                        Text("Minimum confidence required to display results.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Smoothing Window:")
                            Spacer()
                            Text("\(smoothingWindow) samples")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: .init(
                            get: { Double(smoothingWindow) },
                            set: { smoothingWindow = Int($0) }
                        ), in: 3...10, step: 1) {
                            Text("Smoothing Window")
                        }
                        
                        Text("Number of recent results used for smoothing. Higher = more stable but slower to adapt.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Features") {
                    Toggle("Enable Chord Detection", isOn: $enableChordDetection)
                    
                    if enableChordDetection {
                        Text("Detect and display chord progressions in real-time.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }
                
                Section("Performance") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Status:")
                            .font(.headline)
                        
                        HStack {
                            Circle()
                                .fill(inputManager.isProcessing ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text("Audio Processing: \(inputManager.isProcessing ? "Active" : "Inactive")")
                                .font(.caption)
                        }
                        
                        HStack {
                            Circle()
                                .fill(inputManager.currentSource != .none ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text("Input Source: \(inputManager.currentSource != .none ? "Connected" : "None")")
                                .font(.caption)
                        }
                        
                        HStack {
                            Circle()
                                .fill(AudioAnalyzer.shared.isAvailable ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text("Essentia Engine: \(AudioAnalyzer.shared.isAvailable ? "Available" : "Unavailable")")
                                .font(.caption)
                        }
                        
                        Text("Essentia Version: \(AudioAnalyzer.shared.version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("About") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Real-Time Music Analyzer")
                            .font(.headline)
                        
                        Text("Powered by Essentia audio analysis library")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Features:")
                            .font(.subheadline)
                            .padding(.top, 4)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("• Real-time BPM detection")
                            Text("• Musical key and scale analysis")
                            Text("• Chord progression detection")
                            Text("• Adaptive confidence smoothing")
                            Text("• Live audio spectrum visualization")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        applySettings()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        resetToDefaults()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() {
        // Load current settings from UserDefaults or engine
        analysisInterval = 2.0
        confidenceThreshold = 0.5
        enableChordDetection = true
        maxAnalysisTime = 10.0
        smoothingWindow = 5
    }
    
    private func applySettings() {
        // Apply settings to the analysis engine
        // In a real implementation, you would update the engine parameters
        UserDefaults.standard.set(analysisInterval, forKey: "analysisInterval")
        UserDefaults.standard.set(confidenceThreshold, forKey: "confidenceThreshold")
        UserDefaults.standard.set(enableChordDetection, forKey: "enableChordDetection")
        UserDefaults.standard.set(maxAnalysisTime, forKey: "maxAnalysisTime")
        UserDefaults.standard.set(smoothingWindow, forKey: "smoothingWindow")
        
        print("Settings applied:")
        print("- Analysis Interval: \(analysisInterval)s")
        print("- Confidence Threshold: \(confidenceThreshold)")
        print("- Chord Detection: \(enableChordDetection)")
        print("- Max Analysis Time: \(maxAnalysisTime)s")
        print("- Smoothing Window: \(smoothingWindow)")
    }
    
    private func resetToDefaults() {
        analysisInterval = 2.0
        confidenceThreshold = 0.5
        enableChordDetection = true
        maxAnalysisTime = 10.0
        smoothingWindow = 5
        selectedSampleRate = 44100
    }
}