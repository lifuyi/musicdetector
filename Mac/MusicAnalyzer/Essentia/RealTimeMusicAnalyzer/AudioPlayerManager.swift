//
//  AudioPlayerManager.swift
//  Audio playback with real-time analysis
//

import Foundation
import AVFoundation
import Combine

class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 1.0
    @Published var playbackRate: Float = 1.0
    @Published var currentFile: URL?
    @Published var errorMessage: String?
    @Published var spectrumData: [Float] = Array(repeating: 0, count: 64)
    
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    
    // Real-time analysis during playback
    var onPlaybackAudioData: ((AudioBuffer) -> Void)?
    
    override init() {
        super.init()
        setupAudioEngine()
    }
    
    deinit {
        // Clean up audio engine on dealloc
        stopPlayback()
        playerNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        print("🧹 AudioPlayerManager cleaned up")
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() {
        print("🔧 Setting up audio engine...")
        
        // Use a simpler approach with AVAudioPlayer for reliable audio output
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        // Attach the player node
        audioEngine.attach(playerNode)
        
        // Get the output format
        let outputFormat = audioEngine.outputNode.outputFormat(forBus: 0)
        print("📊 Output format: \(outputFormat)")
        
        // Connect player directly to output for reliable sound
        audioEngine.connect(playerNode, to: audioEngine.outputNode, format: nil)
        
        // Set volume to maximum to ensure sound
        audioEngine.mainMixerNode.outputVolume = 1.0
        
        // Install tap for analysis on the player node instead of mixer
        playerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, time in
            self?.processPlaybackAudio(buffer)
        }
        
        do {
            try audioEngine.start()
            print("✅ Audio engine started successfully")
            print("🔊 Engine running: \(audioEngine.isRunning)")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }
    
    // MARK: - File Playback Control
    
    func loadAndPlayFile(_ url: URL) {
        print("🎵 Loading file: \(url.lastPathComponent)")
        stopPlayback()
        
        do {
            // Use AVAudioPlayer for simpler, more reliable playback
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            guard let player = audioPlayer else {
                print("❌ Failed to create AVAudioPlayer")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load audio file"
                }
                return
            }
            
            print("📁 File loaded - Duration: \(player.duration)s")
            print("📁 File format: \(url.pathExtension)")
            
            // Update file info
            DispatchQueue.main.async {
                self.currentFile = url
                self.duration = player.duration
                self.currentTime = 0
                self.errorMessage = nil
            }
            
            // Start playback immediately
            print("▶️ Starting simple playback...")
            let success = player.play()
            
            if success {
                startPlaybackTimer()
                DispatchQueue.main.async {
                    self.isPlaying = true
                    self.isPaused = false
                }
                print("✅ File loaded and playing: \(url.lastPathComponent)")
                print("📊 Playback status - isPlaying: \(self.isPlaying), isPaused: \(self.isPaused)")
            } else {
                print("❌ Failed to start playback")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to start playback"
                }
            }
            
        } catch {
            print("❌ Failed to load file: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load file: \(error.localizedDescription)"
                self.currentFile = nil
            }
        }
    }
    
    func startPlayback() {
        guard let player = audioPlayer else { 
            print("❌ Cannot start playback: no audio player")
            return 
        }
        
        player.play()
        startPlaybackTimer()
        
        DispatchQueue.main.async {
            self.isPlaying = true
            self.isPaused = false
            print("✅ Playback started successfully - isPlaying: \(self.isPlaying)")
        }
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        stopPlaybackTimer()
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isPaused = true
        }
    }
    
    func resumePlayback() {
        audioPlayer?.play()
        startPlaybackTimer()
        
        DispatchQueue.main.async {
            self.isPlaying = true
            self.isPaused = false
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        stopPlaybackTimer()
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isPaused = false
            self.currentTime = 0
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.playbackCompleted()
        }
    }
    
    func seekTo(_ time: TimeInterval) {
        guard let player = audioPlayer else { return }
        
        player.currentTime = time
        
        DispatchQueue.main.async {
            self.currentTime = time
        }
    }
    
    func setVolume(_ volume: Float) {
        self.volume = max(0.0, min(1.0, volume))
        audioEngine.mainMixerNode.outputVolume = self.volume
    }
    
    func setPlaybackRate(_ rate: Float) {
        // Note: Advanced playback rate control requires additional audio processing
        self.playbackRate = max(0.5, min(2.0, rate))
        // Implementation would require pitch shifting to maintain key
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
        guard let player = audioPlayer else { return }
        
        DispatchQueue.main.async {
            self.currentTime = player.currentTime
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
        guard isPlaying else { return }
        
        // Safety check for array bounds
        guard frameLength > 0 else { return }
        
        // Check if there's actual audio data (not silence) - sample a few points
        let samplePoints = min(10, frameLength)
        let hasAudioData = (0..<samplePoints).contains { i in
            abs(floatChannelData[0][i]) > 0.001
        }
        
        guard hasAudioData else { return }
        
        // Create audio buffer for real-time analysis with safe data copy
        do {
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
        } catch {
            print("❌ Error processing audio buffer: \(error)")
        }
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
}