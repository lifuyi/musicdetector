//
//  AnalysisViews.swift
//  UI components for music analysis display
//

import SwiftUI

// MARK: - Audio Level Visualization
struct AudioLevelView: View {
    let level: Float
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Audio Level")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 8)
                    .cornerRadius(4)
                
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.green, .yellow, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: CGFloat(level) * 200, height: 8)
                    .cornerRadius(4)
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
            .frame(width: 200)
        }
    }
}

// MARK: - Current Analysis Display
struct CurrentAnalysisView: View {
    let result: MusicAnalysisResult?
    let analysisTime: TimeInterval
    let confidence: Float
    
    var body: some View {
        VStack(spacing: 16) {
            // Analysis Timer
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                Text("Analysis Time: \(String(format: "%.1f", analysisTime))s")
                    .font(.caption)
                    .monospacedDigit()
            }
            
            if let result = result {
                VStack(spacing: 12) {
                    // BPM Display
                    VStack(spacing: 4) {
                        Text("BPM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f", result.bpm))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    // Key Display
                    VStack(spacing: 4) {
                        Text("Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(result.key) \(result.scale)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    // Confidence Indicator
                    VStack(spacing: 4) {
                        Text("Confidence")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(String(format: "%.1f%%", confidence * 100))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ConfidenceIndicator(confidence: confidence)
                        }
                    }
                    
                    // Current Chords
                    if !result.chords.isEmpty {
                        VStack(spacing: 4) {
                            Text("Current Chords")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 4) {
                                ForEach(result.chords.prefix(4)) { chord in
                                    Text(chord.chord)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            } else {
                VStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}

// MARK: - Confidence Indicator
struct ConfidenceIndicator: View {
    let confidence: Float
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(confidence > Float(index) * 0.2 ? confidenceColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
}

// MARK: - Spectrum Visualization
struct SpectrumView: View {
    @ObservedObject var inputManager: AudioInputManager
    @State private var spectrumData: [Float] = Array(repeating: 0, count: 64)
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Audio Spectrum")
                    .font(.headline)
                Spacer()
                if inputManager.isProcessing {
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                            .opacity(0.8)
                        Text(statusText)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(statusColor)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<spectrumData.count, id: \.self) { index in
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(width: 8, height: max(2, CGFloat(spectrumData[index]) * 150))
                        .animation(.easeInOut(duration: 0.1), value: spectrumData[index])
                }
            }
            .frame(height: 150)
            .padding(.horizontal)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) {_ in
            updateSpectrum()
        }
    }
    
    private func updateSpectrum() {
        // Simulate spectrum data based on audio level
        let level = inputManager.audioLevel
        spectrumData = spectrumData.enumerated().map { index, _ in
            let frequency = Float(index) / Float(spectrumData.count)
            let amplitude = level * (1.0 - frequency) * Float.random(in: 0.8...1.2)
            return max(0, min(1, amplitude))
        }
    }
    
    private var statusColor: Color {
        switch inputManager.currentSource {
        case .microphone: return .red
        case .file: return .blue
        case .url: return .purple
        case .none: return .gray
        }
    }
    
    private var statusText: String {
        switch inputManager.currentSource {
        case .microphone: return "LIVE"
        case .file: return "FILE"
        case .url: return "STREAM"
        case .none: return "IDLE"
        }
    }
}

// MARK: - Analysis Detail View
struct AnalysisDetailView: View {
    @ObservedObject var analysisEngine: RealTimeAnalysisEngine
    let isAnalyzing: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Analysis Details")
                    .font(.headline)
                Spacer()
                if isAnalyzing {
                    Text("\(analysisEngine.analysisHistory.count) results")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            Divider()
            
            if isAnalyzing && !analysisEngine.analysisHistory.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(analysisEngine.analysisHistory.reversed()) { result in
                            AnalysisHistoryRow(result: result)
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text(isAnalyzing ? "Listening for music..." : "Start analysis to see results")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if isAnalyzing {
                        Text("Results will appear as confidence increases")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Analysis History Row
struct AnalysisHistoryRow: View {
    let result: MusicAnalysisResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("BPM: \(String(format: "%.1f", result.bpm))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Key: \(result.key) \(result.scale)")
                        .font(.subheadline)
                }
                
                if !result.chords.isEmpty {
                    HStack {
                        Text("Chords:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(result.chords.map(\.chord).joined(separator: ", "))
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            ConfidenceIndicator(confidence: result.confidence)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}