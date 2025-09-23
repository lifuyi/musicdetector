//
//  AudioPlayerView.swift
//  Audio player with real-time analysis display
//

import SwiftUI

struct AudioPlayerView: View {
    @ObservedObject var playerManager: AudioPlayerManager
    @ObservedObject var analysisEngine: RealTimeAnalysisEngine
    
    @State private var showingFilePicker = false
    @State private var userIsSeeking = false
    @State private var seekPosition: Float = 0
    
    var body: some View {
        VStack(spacing: 16) {
            // File Info Header
            if let fileInfo = playerManager.getFileInfo() {
                FileInfoHeader(fileInfo: fileInfo)
            } else {
                NoFileHeader(onSelectFile: { showingFilePicker = true })
            }
            
            // Real-time Analysis Display During Playback
            if playerManager.isPlaying || playerManager.isPaused {
                PlaybackAnalysisDisplay(
                    currentResult: analysisEngine.currentResult,
                    isPlaying: playerManager.isPlaying
                )
            }
            
            // Playback Controls
            PlaybackControlsView(
                playerManager: playerManager,
                userIsSeeking: $userIsSeeking,
                seekPosition: $seekPosition
            )
            
            // Volume and Speed Controls
            AudioControlsView(playerManager: playerManager)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .sheet(isPresented: $showingFilePicker) {
            AudioFilePicker { url in
                playerManager.loadAndPlayFile(url)
                analysisEngine.startAnalysis()
            }
        }
        .onReceive(playerManager.$currentTime) { _ in
            if !userIsSeeking {
                seekPosition = playerManager.getPlaybackPosition()
            }
        }
        .onAppear {
            // Connect player to analysis engine
            playerManager.onPlaybackAudioData = { audioBuffer in
                analysisEngine.processAudioData(audioBuffer)
            }
        }
    }
}

// MARK: - File Info Header

struct FileInfoHeader: View {
    let fileInfo: (name: String, duration: String, format: String)
    
    var body: some View {
        HStack {
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
            
            Image(systemName: "music.note")
                .font(.title2)
                .foregroundColor(.blue)
        }
    }
}

struct NoFileHeader: View {
    let onSelectFile: () -> Void
    
    var body: some View {
        Button(action: onSelectFile) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Select Audio File to Play")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "folder")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Playback Analysis Display

struct PlaybackAnalysisDisplay: View {
    let currentResult: MusicAnalysisResult?
    let isPlaying: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Live Analysis")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                HStack {
                    Circle()
                        .fill(isPlaying ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    Text(isPlaying ? "ANALYZING" : "PAUSED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(isPlaying ? .green : .orange)
                }
            }
            
            if let result = currentResult {
                HStack(spacing: 20) {
                    // BPM Display
                    VStack(spacing: 4) {
                        Text("BPM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f", result.bpm))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    // Key Display
                    VStack(spacing: 4) {
                        Text("Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(result.key) \(result.scale)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    // Current Chord
                    VStack(spacing: 4) {
                        Text("Chord")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let currentChord = result.chords.first {
                            Text(currentChord.chord)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        } else {
                            Text("—")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Chord Progression Timeline
                if !result.chords.isEmpty {
                    ChordProgressionView(chords: result.chords)
                }
                
            } else {
                Text("Analyzing audio...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 60)
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Chord Progression View

struct ChordProgressionView: View {
    let chords: [ChordDetection]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Chord Progression")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chords) { chord in
                        VStack(spacing: 2) {
                            Text(chord.chord)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 24)
                                .background(confidenceColor(chord.confidence))
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
    
    private func confidenceColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
}

// MARK: - Playback Controls

struct PlaybackControlsView: View {
    @ObservedObject var playerManager: AudioPlayerManager
    @Binding var userIsSeeking: Bool
    @Binding var seekPosition: Float
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress Bar
            VStack(spacing: 4) {
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
                
                Slider(value: $seekPosition, in: 0...1) { editing in
                    userIsSeeking = editing
                    if !editing {
                        playerManager.setPlaybackPosition(seekPosition)
                    }
                }
                .accentColor(.blue)
            }
            
            // Control Buttons
            HStack(spacing: 24) {
                // Previous/Rewind
                Button(action: { playerManager.seekTo(0) }) {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                // Play/Pause
                Button(action: togglePlayback) {
                    Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                }
                
                // Stop
                Button(action: playerManager.stopPlayback) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
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
        }
    }
}

// MARK: - Audio Controls

struct AudioControlsView: View {
    @ObservedObject var playerManager: AudioPlayerManager
    
    var body: some View {
        HStack(spacing: 20) {
            // Volume Control
            HStack {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: Binding(
                    get: { playerManager.volume },
                    set: { playerManager.setVolume($0) }
                ), in: 0...1)
                .frame(width: 80)
                
                Text("\(Int(playerManager.volume * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 30)
            }
            
            Spacer()
            
            // Playback Rate (Future Enhancement)
            HStack {
                Text("Speed:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("1.0x")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
        }
    }
}