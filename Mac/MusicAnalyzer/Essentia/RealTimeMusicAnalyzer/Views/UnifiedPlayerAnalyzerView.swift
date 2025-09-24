//
//  UnifiedPlayerAnalyzerView.swift
//  Unified audio player with real-time analysis
//  Upload file -> immediate playback + analysis
//

import SwiftUI
import Combine

struct UnifiedPlayerAnalyzerView: View {
    @ObservedObject var playerManager: AudioPlayerManager
    @ObservedObject var analysisEngine: RealTimeAnalysisEngine
    
    @State private var showingFilePicker = false
    @State private var userIsSeeking = false
    @State private var seekPosition: Float = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Top Three Buttons
            TopControlsView(
                hasFile: playerManager.currentFile != nil,
                isPlaying: playerManager.isPlaying,
                onUpload: { showingFilePicker = true },
                onPlayPause: togglePlayback,
                onStop: stopAndClear
            )
            
            // File Info (when file is loaded)
            if let fileInfo = playerManager.getFileInfo() {
                FileInfoDisplay(fileInfo: fileInfo)
            }
            
            // Real-time Analysis Display (during playback)
            if playerManager.isPlaying || playerManager.isPaused {
                RealTimeAnalysisView(
                    currentResult: analysisEngine.currentResult,
                    isPlaying: playerManager.isPlaying
                )
                
                // Spectrum Visualization during playback
                if playerManager.isPlaying {
                    SpectrumVisualizationView(playerManager: playerManager)
                }
            }
            
            // Playback Progress and Seek
            if playerManager.currentFile != nil {
                PlaybackProgressView(
                    playerManager: playerManager,
                    userIsSeeking: $userIsSeeking,
                    seekPosition: $seekPosition
                )
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingFilePicker) {
            AudioFilePicker { url in
                // Load and start playing the file first
                print("📂 File selected: \(url.lastPathComponent)")
                print("📂 File path: \(url.path)")
                print("📂 File exists: \(FileManager.default.fileExists(atPath: url.path))")
                
                playerManager.loadAndPlayFile(url)
                
                // Start analysis after a short delay to ensure playback is started
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if playerManager.isPlaying {
                        print("🔥 Starting analysis for uploaded file")
                        analysisEngine.startAnalysis()
                    } else {
                        print("⚠️ Playback not started, checking for errors...")
                        if let errorMessage = playerManager.errorMessage {
                            print("❌ Playback error: \(errorMessage)")
                        }
                    }
                }
            }
        }
        .onReceive(playerManager.$currentTime) { _ in
            if !userIsSeeking {
                seekPosition = playerManager.getPlaybackPosition()
            }
        }
        .onReceive(playerManager.$isPlaying) { isPlaying in
            // Only stop analysis when playback stops
            if !isPlaying {
                analysisEngine.stopAnalysis()
            }
        }
        .onAppear {
            // Connect player to analysis engine
            playerManager.onPlaybackAudioData = { audioBuffer in
                analysisEngine.processAudioData(audioBuffer)
            }
        }
    }
    
    private func togglePlayback() {
        if playerManager.isPlaying {
            playerManager.pausePlayback()
        } else if playerManager.isPaused {
            playerManager.resumePlayback()
        } else if playerManager.currentFile != nil {
            playerManager.startPlayback()
            // Analysis will start automatically when isPlaying becomes true
        }
    }
    
    private func stopAndClear() {
        playerManager.stopPlayback()
        analysisEngine.stopAnalysis()
        playerManager.clearFile()
    }
}

// MARK: - Top Controls View

struct TopControlsView: View {
    let hasFile: Bool
    let isPlaying: Bool
    let onUpload: () -> Void
    let onPlayPause: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Upload Button
            Button(action: onUpload) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                    Text("Upload & Play")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .cornerRadius(10)
            }
            
            // Play/Pause Button
            Button(action: onPlayPause) {
                HStack {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                    Text(isPlaying ? "Pause" : "Play")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(hasFile ? Color.green : Color.gray)
                .cornerRadius(10)
            }
            .disabled(!hasFile)
            
            // Stop Button
            Button(action: onStop) {
                HStack {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                    Text("Stop")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(hasFile ? Color.red : Color.gray)
                .cornerRadius(10)
            }
            .disabled(!hasFile)
        }
    }
}

// MARK: - File Info Display

struct FileInfoDisplay: View {
    let fileInfo: (name: String, duration: String, format: String)
    
    var body: some View {
        HStack {
            Image(systemName: "music.note")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(fileInfo.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                HStack {
                    Text(fileInfo.format)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(fileInfo.duration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Real-time Analysis View

struct RealTimeAnalysisView: View {
    let currentResult: MusicAnalysisResult?
    let isPlaying: Bool
    @State private var isKeyAdjustmentVisible = false
    @State private var adjustedKey: String = ""
    @State private var adjustedScale: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Analysis Status Header
            HStack {
                Text("Real-time Analysis")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack {
                    Circle()
                        .fill(isPlaying ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    
                    Text(isPlaying ? "ANALYZING" : "PAUSED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(isPlaying ? .green : .orange)
                }
            }
            
            if let result = currentResult {
                // Main Analysis Results
                HStack(spacing: 24) {
                    // BPM
                    AnalysisMetricView(
                        title: "BPM",
                        value: String(format: "%.1f", result.bpm),
                        color: .blue
                    )
                    
                    Divider()
                        .frame(height: 60)
                    
                    // Key with adjustment capability
                    VStack(spacing: 8) {
                        HStack {
                            Text("Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            // Show edit button for low confidence
                            if result.confidence < 0.7 {
                                Button(action: { isKeyAdjustmentVisible.toggle() }) {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        HStack {
                            Text("\(adjustedKey.isEmpty ? result.key : adjustedKey) \(adjustedScale.isEmpty ? result.scale : adjustedScale)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            // Confidence indicator
                            ConfidenceIcon(confidence: result.confidence)
                        }
                        
                        Text("Confidence: \(String(format: "%.1f%%", result.confidence * 100))")
                            .font(.caption2)
                            .foregroundColor(confidenceColor(result.confidence))
                    }
                    
                    Divider()
                        .frame(height: 60)
                    
                    // Current Chord
                    VStack(spacing: 8) {
                        Text("Current Chord")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let currentChord = result.chords.first {
                            Text(currentChord.chord)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                        } else {
                            Text("—")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Key Adjustment Panel (when visible)
                if isKeyAdjustmentVisible {
                    KeyAdjustmentPanel(
                        currentKey: result.key,
                        currentScale: result.scale,
                        onAdjust: { newKey, newScale in
                            adjustedKey = newKey
                            adjustedScale = newScale
                            isKeyAdjustmentVisible = false
                        },
                        onCancel: {
                            isKeyAdjustmentVisible = false
                        }
                    )
                }
                
                // Chord Progression Timeline
                if !result.chords.isEmpty {
                    ChordProgressionTimeline(chords: result.chords)
                }
                
            } else {
                Text("Analyzing audio...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 80)
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func confidenceColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.9...1.0: return .green
        case 0.7..<0.9: return .blue
        case 0.5..<0.7: return .orange
        default: return .red
        }
    }
}

// MARK: - Supporting Views

struct AnalysisMetricView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

struct ConfidenceIcon: View {
    let confidence: Float
    
    var body: some View {
        Group {
            if confidence < 0.5 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            } else if confidence < 0.7 {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
            } else if confidence >= 0.9 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.blue)
            }
        }
        .font(.caption)
    }
}

struct KeyAdjustmentPanel: View {
    let currentKey: String
    let currentScale: String
    let onAdjust: (String, String) -> Void
    let onCancel: () -> Void
    
    @State private var selectedKey: String
    @State private var selectedScale: String
    
    private let keys = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private let scales = ["major", "minor"]
    
    init(currentKey: String, currentScale: String, onAdjust: @escaping (String, String) -> Void, onCancel: @escaping () -> Void) {
        self.currentKey = currentKey
        self.currentScale = currentScale
        self.onAdjust = onAdjust
        self.onCancel = onCancel
        self._selectedKey = State(initialValue: currentKey)
        self._selectedScale = State(initialValue: currentScale)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Adjust Key Detection")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Key", selection: $selectedKey) {
                        ForEach(keys, id: \.self) { key in
                            Text(key).tag(key)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                VStack(alignment: .leading) {
                    Text("Scale")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Scale", selection: $selectedScale) {
                        ForEach(scales, id: \.self) { scale in
                            Text(scale.capitalized).tag(scale)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .foregroundColor(.secondary)
                
                Button("Apply") {
                    onAdjust(selectedKey, selectedScale)
                }
                .foregroundColor(.blue)
                .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ChordProgressionTimeline: View {
    let chords: [ChordDetection]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chord Progression")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(chords.prefix(10)) { chord in
                        VStack(spacing: 4) {
                            Text(chord.chord)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 45, height: 28)
                                .background(chordConfidenceColor(chord.confidence))
                                .cornerRadius(6)
                            
                            Text(String(format: "%.1fs", chord.startTime))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func chordConfidenceColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
}

// MARK: - Playback Progress View

struct PlaybackProgressView: View {
    @ObservedObject var playerManager: AudioPlayerManager
    @Binding var userIsSeeking: Bool
    @Binding var seekPosition: Float
    
    var body: some View {
        VStack(spacing: 8) {
            // Time labels
            HStack {
                Text(playerManager.formatTime(playerManager.currentTime))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(playerManager.formatTime(playerManager.duration))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            
            // Progress slider
            Slider(value: $seekPosition, in: 0...1) { editing in
                userIsSeeking = editing
                if !editing {
                    playerManager.setPlaybackPosition(seekPosition)
                }
            }
            .accentColor(.blue)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Spectrum Visualization

struct SpectrumVisualizationView: View {
    @ObservedObject var playerManager: AudioPlayerManager
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Audio Spectrum")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<playerManager.spectrumData.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(LinearGradient(
                            colors: [.blue, .green, .yellow, .red],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(width: 4, height: max(2, CGFloat(playerManager.spectrumData[index]) * 60))
                        .animation(.easeInOut(duration: 0.1), value: playerManager.spectrumData[index])
                }
            }
            .frame(height: 60)
            .padding(.horizontal)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}