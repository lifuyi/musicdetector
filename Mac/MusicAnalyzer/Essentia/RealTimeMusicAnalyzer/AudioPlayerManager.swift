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
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        
        let outputFormat = audioEngine.outputNode.outputFormat(forBus: 0)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: outputFormat)
        
        // Install tap for real-time analysis during playback
        audioEngine.mainMixerNode.installTap(onBus: 0, bufferSize: 4096, format: outputFormat) { [weak self] buffer, time in
            self?.processPlaybackAudio(buffer)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    // MARK: - File Playback Control
    
    func loadAndPlayFile(_ url: URL) {
        stopPlayback()
        
        do {
            // Load audio file
            audioFile = try AVAudioFile(forReading: url)
            
            guard let audioFile = audioFile else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load audio file"
                }
                return
            }
            
            // Update file info
            DispatchQueue.main.async {
                self.currentFile = url
                self.duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
                self.currentTime = 0
                self.errorMessage = nil
            }
            
            // Schedule file for playback
            playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.playbackCompleted()
                }
            }
            
            // Start playback
            startPlayback()
            
            print("✅ File loaded and playing: \(url.lastPathComponent)")
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load file: \(error.localizedDescription)"
                self.currentFile = nil
            }
        }
    }
    
    func startPlayback() {
        guard audioFile != nil else { return }
        
        do {
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            
            playerNode.play()
            startPlaybackTimer()
            
            DispatchQueue.main.async {
                self.isPlaying = true
                self.isPaused = false
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Playback failed: \(error.localizedDescription)"
            }
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
        guard let audioFile = audioFile else { return }
        
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
        guard let floatChannelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // Only process if we're actually playing
        guard isPlaying else { return }
        
        // Create audio buffer for real-time analysis
        let audioBuffer = AudioBuffer(
            data: Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameLength)),
            sampleRate: buffer.format.sampleRate,
            channels: channelCount,
            timestamp: Date()
        )
        
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
        // Implementation for real-time spectrum analysis
        // This could be used for enhanced visualization
        return Array(repeating: 0, count: 64)
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