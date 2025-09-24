//
//  AudioPlayerManager.swift
//  Audio playback with real-time analysis
//

import Foundation
import AVFoundation
import Combine

class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 1.0
    @Published var playbackRate: Float = 1.0
    @Published var currentFile: URL?
    @Published var errorMessage: String?
    @Published var spectrumData: [Float] = Array(repeating: 0, count: 64)
    
    private var audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var playbackTimer: Timer?
    
    // Real-time analysis during playback
    var onPlaybackAudioData: ((AudioBuffer) -> Void)?
    
    override init() {
        super.init()
        setupAudioEngine()
    }
    
    deinit {
        // Clean up audio engine on dealloc
        print("🧹 Cleaning up AudioPlayerManager...")
        stopPlayback()
        playerNode.removeTap(onBus: 0)
        // Remove tap from mixer node as well
        audioEngine.mainMixerNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        print("🧹 AudioPlayerManager cleaned up")
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() {
        print("🔧 Setting up audio engine...")
        
        // Reset the audio engine
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        // Attach the player node
        audioEngine.attach(playerNode)
        print("🔗 Player node attached to audio engine")
        
        // Connect player directly to output for reliable sound
        // Using the mixer node for better control
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)
        audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: nil)
        print("🔗 Player node connected through mixer to output node")
        
        // Set initial volume
        playerNode.volume = volume
        audioEngine.mainMixerNode.outputVolume = 1.0
        print("🔊 Volume set - Player: \(playerNode.volume), Mixer: \(audioEngine.mainMixerNode.outputVolume)")
        
        // Install tap for analysis on the mixer node for better capture
        audioEngine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, time in
            self?.processPlaybackAudio(buffer)
        }
        print("🔍 Tap installed on mixer node for real-time analysis")
        
        do {
            try audioEngine.start()
            print("✅ Audio engine started successfully")
            print("🔊 Engine running: \(audioEngine.isRunning)")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
        }
    }
    
    // MARK: - File Playback Control
    
    func loadAndPlayFile(_ url: URL) {
        print("🎵 Loading file: \(url.lastPathComponent)")
        stopPlayback()
        
        do {
            // Load audio file for AVAudioEngine
            audioFile = try AVAudioFile(forReading: url)
            
            guard let file = audioFile else {
                print("❌ Failed to create AVAudioFile")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load audio file"
                }
                return
            }
            
            print("📁 File loaded - Duration: \(Double(file.length) / file.processingFormat.sampleRate)s")
            print("📁 File format: \(url.pathExtension)")
            print("📁 File sample rate: \(file.processingFormat.sampleRate)")
            print("📁 File channel count: \(file.processingFormat.channelCount)")
            
            // Update file info
            DispatchQueue.main.async {
                self.currentFile = url
                self.duration = Double(file.length) / file.processingFormat.sampleRate
                self.currentTime = 0
                self.errorMessage = nil
            }
            
            // Schedule file for playback
            print("📅 Scheduling file for playback...")
            playerNode.scheduleFile(file, at: nil) { [weak self] in
                print("⏹ File playback completed")
                DispatchQueue.main.async {
                    self?.playbackCompleted()
                }
            }
            
            // Start playback immediately
            print("▶️ Starting engine playback...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.startPlayback()
            }
            
            print("✅ File loaded and scheduled: \(url.lastPathComponent)")
            print("📊 Playback status - isPlaying: \(self.isPlaying), isPaused: \(self.isPaused)")
            
        } catch {
            print("❌ Failed to load file: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load file: \(error.localizedDescription)"
                self.currentFile = nil
            }
        }
    }
    
    func startPlayback() {
        guard audioFile != nil else { 
            print("❌ Cannot start playback: no audio file loaded")
            return 
        }
        
        print("🔊 Starting playback - Audio engine running: \(audioEngine.isRunning)")
        print("🔊 Player node status: \(playerNode.isPlaying ? "playing" : "stopped")")
        
        // Ensure audio engine is running
        ensureAudioEngineRunning()
        
        playerNode.play()
        startPlaybackTimer()
        
        DispatchQueue.main.async {
            self.isPlaying = true
            self.isPaused = false
            print("✅ Playback started successfully - isPlaying: \(self.isPlaying)")
            print("🔊 Player node is now playing: \(self.playerNode.isPlaying)")
        }
    }
    
    func pausePlayback() {
        playerNode.pause()
        stopPlaybackTimer()
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isPaused = true
        }
    }
    
    func resumePlayback() {
        playerNode.play()
        startPlaybackTimer()
        
        DispatchQueue.main.async {
            self.isPlaying = true
            self.isPaused = false
        }
    }
    
    func stopPlayback() {
        playerNode.stop()
        stopPlaybackTimer()
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isPaused = false
            self.currentTime = 0
        }
    }
    
    func seekTo(_ time: TimeInterval) {
        guard let file = audioFile else { return }
        
        let wasPlaying = isPlaying
        stopPlayback()
        
        // Calculate frame position
        let sampleRate = file.processingFormat.sampleRate
        let framePosition = AVAudioFramePosition(time * sampleRate)
        
        // Schedule from new position
        let remainingFrames = file.length - framePosition
        if remainingFrames > 0 {
            playerNode.scheduleSegment(file, 
                                     startingFrame: framePosition, 
                                     frameCount: AVAudioFrameCount(remainingFrames), 
                                     at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.playbackCompleted()
                }
            }
        }
        
        DispatchQueue.main.async {
            self.currentTime = time
        }
        
        if wasPlaying {
            startPlayback()
        }
    }
    
    func setVolume(_ volume: Float) {
        self.volume = max(0.0, min(1.0, volume))
        playerNode.volume = self.volume
    }
    
    func setPlaybackRate(_ rate: Float) {
        // Note: AVAudioPlayerNode supports playback rate changes
        self.playbackRate = max(0.5, min(2.0, rate))
        playerNode.rate = self.playbackRate
    }
    
    // MARK: - Playback Timer
    
    private func startPlaybackTimer() {
        stopPlaybackTimer()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePlaybackTime()
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func updatePlaybackTime() {
        guard audioFile != nil else { return }
        
        if let nodeTime = playerNode.lastRenderTime,
           let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            let currentSeconds = Double(playerTime.sampleTime) / playerTime.sampleRate
            
            DispatchQueue.main.async {
                self.currentTime = currentSeconds
            }
        }
    }
    
    private func playbackCompleted() {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isPaused = false
        }
        stopPlaybackTimer()
    }
    
    // MARK: - Real-time Analysis During Playback
    
    private func processPlaybackAudio(_ buffer: AVAudioPCMBuffer) {
        // Safety checks to prevent crashes
        guard let floatChannelData = buffer.floatChannelData,
              buffer.frameLength > 0,
              buffer.format.channelCount > 0 else { 
            return 
        }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // Only process if we're actually playing
        guard isPlaying else { 
            print("🔇 Skipping processing - not playing")
            return 
        }
        
        // Safety check for array bounds
        guard frameLength > 0 else { 
            print("🔇 Skipping processing - empty buffer")
            return 
        }
        
        // Check if there's actual audio data (not silence) - sample a few points
        let samplePoints = min(10, frameLength)
        let hasAudioData = (0..<samplePoints).contains { i in
            abs(floatChannelData[0][i]) > 0.001
        }
        
        guard hasAudioData else { 
            print("🔇 Skipping processing - no audio data (silence)")
            return 
        }
        
        print("🔊 Processing audio buffer - frame length: \(frameLength), channels: \(channelCount)")
        
        // Create audio buffer for real-time analysis with safe data copy
        let audioData = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameLength))
        let audioBuffer = AudioBuffer(
            data: audioData,
            sampleRate: buffer.format.sampleRate,
            channels: channelCount,
            timestamp: Date()
        )
        
        // Calculate spectrum for visualization
        let spectrum = calculateSpectrum(from: audioData)
        DispatchQueue.main.async {
            self.spectrumData = spectrum
        }
        
        // Send to analysis engine for real-time processing
        onPlaybackAudioData?(audioBuffer)
    }
    
    // MARK: - Utility Methods
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func getPlaybackPosition() -> Float {
        guard duration > 0 else { return 0 }
        return Float(currentTime / duration)
    }
    
    func setPlaybackPosition(_ position: Float) {
        let newTime = Double(position) * duration
        seekTo(newTime)
    }
    
    func clearFile() {
        stopPlayback()
        audioFile = nil
        DispatchQueue.main.async {
            self.currentFile = nil
            self.duration = 0
            self.currentTime = 0
            self.errorMessage = nil
        }
    }
    
    func getFileInfo() -> (name: String, duration: String, format: String)? {
        guard let currentFile = currentFile else { return nil }
        
        let name = currentFile.lastPathComponent
        let durationString = formatTime(duration)
        let format = currentFile.pathExtension.uppercased()
        
        return (name: name, duration: durationString, format: format)
    }
    
    // MARK: - Advanced Features
    
    func enableLooping(_ enabled: Bool) {
        // Implementation for looping playback
    }
    
    func getCurrentSpectrum() -> [Float] {
        return spectrumData
    }
    
    private func calculateSpectrum(from audioData: [Float]) -> [Float] {
        let fftSize = 512
        let spectrumSize = 64
        
        // Take a chunk of audio data for FFT
        let dataChunk = Array(audioData.prefix(fftSize))
        var spectrum = Array(repeating: Float(0), count: spectrumSize)
        
        // Simple magnitude calculation (simplified FFT)
        for i in 0..<spectrumSize {
            let binStart = i * (dataChunk.count / spectrumSize)
            let binEnd = min(binStart + (dataChunk.count / spectrumSize), dataChunk.count)
            
            var magnitude: Float = 0
            for j in binStart..<binEnd {
                magnitude += abs(dataChunk[j])
            }
            
            spectrum[i] = magnitude / Float(binEnd - binStart)
            spectrum[i] = min(spectrum[i] * 20, 1.0) // Scale and clamp
        }
        
        return spectrum
    }
    
    func exportCurrentPosition() -> PlaybackState {
        return PlaybackState(
            file: currentFile,
            currentTime: currentTime,
            isPlaying: isPlaying,
            volume: volume,
            playbackRate: playbackRate
        )
    }
    
    func restorePlaybackState(_ state: PlaybackState) {
        if let file = state.file {
            loadAndPlayFile(file)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.seekTo(state.currentTime)
                self.setVolume(state.volume)
                if !state.isPlaying {
                    self.pausePlayback()
                }
            }
        }
    }
}

// MARK: - Supporting Structures

struct PlaybackState {
    let file: URL?
    let currentTime: TimeInterval
    let isPlaying: Bool
    let volume: Float
    let playbackRate: Float
}

// MARK: - Audio Session Management (macOS doesn't use AVAudioSession)

extension AudioPlayerManager {
    private func configureAudioSession() {
        // macOS doesn't require AVAudioSession configuration
        // Audio routing is handled by the system
        print("Audio session configured for macOS")
    }
    
    private func ensureAudioEngineRunning() {
        print("🔄 Checking audio engine status - currently running: \(audioEngine.isRunning)")
        guard !audioEngine.isRunning else { 
            print("✅ Audio engine is already running")
            return 
        }
        
        do {
            print("🚀 Starting audio engine...")
            try audioEngine.start()
            print("✅ Audio engine started successfully")
            print("🔊 Engine running: \(audioEngine.isRunning)")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            }
        }
    }
}