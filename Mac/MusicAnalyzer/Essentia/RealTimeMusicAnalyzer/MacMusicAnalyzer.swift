//
//  MacMusicAnalyzer.swift
//  macOS Real-time Music Analysis App
//

import SwiftUI
import AVFoundation
import Combine

@main
struct MacMusicAnalyzerApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    print("Essentia Available: \(AudioAnalyzer.shared.isAvailable)")
                    print("Version: \(AudioAnalyzer.shared.version)")
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

struct MainView: View {
    @StateObject private var inputManager = AudioInputManager()
    @StateObject private var analysisEngine = RealTimeAnalysisEngine()
    @StateObject private var exportManager = ExportManager()
    @StateObject private var midiManager = MIDIOutputManager()
    @StateObject private var playerManager = AudioPlayerManager()
    @State private var isAnalyzing = false
    @State private var analysisStartTime: Date?
    @State private var showSettings = false
    @State private var showExportView = false
    @State private var showPlayerView = false
    
    var body: some View {
        HSplitView {
            // Left Panel - Controls and Input Selection
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Music Analyzer")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Multi-Source Analysis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Input Source Selection
                InputSourceView(
                    inputManager: inputManager,
                    analysisEngine: analysisEngine,
                    playerManager: playerManager
                )
                
                // Current Analysis Results
                if isAnalyzing || inputManager.isProcessing {
                    CurrentAnalysisView(
                        result: analysisEngine.currentResult,
                        analysisTime: analysisStartTime.map { Date().timeIntervalSince($0) } ?? 0,
                        confidence: analysisEngine.confidence
                    )
                }
                
                Spacer()
                
                // Quick Export Buttons
                if !analysisEngine.analysisHistory.isEmpty {
                    VStack(spacing: 8) {
                        Text("Quick Export")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        QuickExportButtons(
                            exportManager: exportManager,
                            analysisEngine: analysisEngine
                        )
                    }
                }
                
                // Action Buttons
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Button(action: { showPlayerView.toggle() }) {
                            VStack(spacing: 4) {
                                Image(systemName: showPlayerView ? "play.slash" : "play.circle")
                                Text(showPlayerView ? "Hide" : "Player")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { showExportView = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button(action: { showSettings = true }) {
                        VStack(spacing: 4) {
                            Image(systemName: "gear")
                            Text("Settings")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(width: 350)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Right Panel - Audio Player and Analysis Details
            VStack(spacing: 0) {
                // Audio Player Section
                if showPlayerView || playerManager.currentFile != nil {
                    AudioPlayerView(
                        playerManager: playerManager,
                        analysisEngine: analysisEngine
                    )
                    .frame(height: 280)
                    
                    Divider()
                } else {
                    // Real-time Spectrum Analyzer
                    SpectrumView(inputManager: inputManager)
                        .frame(height: 200)
                    
                    Divider()
                }
                
                // Analysis History and Details
                AnalysisDetailView(
                    analysisEngine: analysisEngine,
                    isAnalyzing: isAnalyzing || inputManager.isProcessing || playerManager.isPlaying
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(inputManager: inputManager, analysisEngine: analysisEngine)
        }
        .sheet(isPresented: $showExportView) {
            ExportView(
                exportManager: exportManager,
                midiManager: midiManager,
                analysisEngine: analysisEngine
            )
            .frame(width: 600, height: 500)
        }
        .onAppear {
            setupInputManager()
        }
        .onDisappear {
            inputManager.stopAllInputs()
        }
    }
    
    private func setupInputManager() {
        // Connect input manager to analysis engine
        inputManager.onAudioData = { audioData in
            if self.inputManager.isProcessing {
                self.analysisEngine.processAudioData(audioData)
                
                // Start analysis engine if not already running
                if !self.isAnalyzing {
                    self.analysisEngine.startAnalysis()
                    self.analysisStartTime = Date()
                    self.isAnalyzing = true
                }
            }
        }
        
        // Connect audio player to analysis engine
        playerManager.onPlaybackAudioData = { audioData in
            if self.playerManager.isPlaying {
                self.analysisEngine.processAudioData(audioData)
                
                // Start analysis engine if not already running
                if !self.isAnalyzing {
                    self.analysisEngine.startAnalysis()
                    self.analysisStartTime = Date()
                    self.isAnalyzing = true
                }
            }
        }
        
        // Monitor processing state
        inputManager.$isProcessing
            .receive(on: DispatchQueue.main)
            .sink { isProcessing in
                if !isProcessing && !self.playerManager.isPlaying && self.isAnalyzing {
                    // Stop analysis when input stops and player is not playing
                    self.analysisEngine.stopAnalysis()
                    self.isAnalyzing = false
                    self.analysisStartTime = nil
                }
            }
            .store(in: &cancellables)
        
        // Monitor player state
        playerManager.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { isPlaying in
                if !isPlaying && !self.inputManager.isProcessing && self.isAnalyzing {
                    // Stop analysis when player stops and no other input
                    self.analysisEngine.stopAnalysis()
                    self.isAnalyzing = false
                    self.analysisStartTime = nil
                }
            }
            .store(in: &cancellables)
    }
    
    @State private var cancellables = Set<AnyCancellable>()
}