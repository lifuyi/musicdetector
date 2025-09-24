//
//  AudioInputManager.swift
//  Unified audio input management for files, URLs, and microphone
//

import Foundation
import AVFoundation
import Combine

enum AudioInputSource: Equatable {
    case microphone
    case file(URL)
    case url(URL)
    case none
}

enum AudioInputError: Error {
    case invalidURL
    case fileNotFound
    case unsupportedFormat
    case networkError
    case microphoneAccessDenied
    case audioEngineError
}

class AudioInputManager: NSObject, ObservableObject {
    @Published var currentSource: AudioInputSource = .none
    @Published var isProcessing = false
    @Published var audioLevel: Float = 0.0
    @Published var downloadProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private var audioEngine = AVAudioEngine()
    private var audioPlayer: AVAudioPlayer?
    private var audioFile: AVAudioFile?
    private var inputNode: AVAudioInputNode?
    private let bufferSize: AVAudioFrameCount = 4096
    
    var onAudioData: ((AudioBuffer) -> Void)?
    var onAnalysisComplete: ((AudioAnalysisResult?) -> Void)?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        // Request microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                if !granted {
                    self?.errorMessage = "Microphone access denied. Please enable in System Preferences."
                    print("❌ Microphone access denied")
                } else {
                    print("✅ Microphone access granted")
                }
            }
        }
    }
    
    // MARK: - Microphone Input
    
    func startMicrophoneInput() {
        print("🎤 Attempting to start microphone input...")
        stopAllInputs()
        
        do {
            // Check if we have microphone access
            let hasAccess = AVCaptureDevice.authorizationStatus(for: .audio)
            print("🎤 Microphone authorization status: \(hasAccess.rawValue)")
            
            if hasAccess == .denied || hasAccess == .restricted {
                throw AudioInputError.microphoneAccessDenied
            }
            
            inputNode = audioEngine.inputNode
            let inputFormat = inputNode?.outputFormat(forBus: 0)
            
            print("🎤 Input node: \(String(describing: inputNode))")
            print("🎤 Input format: \(String(describing: inputFormat))")
            
            guard let format = inputFormat else {
                print("❌ Failed to get input format")
                throw AudioInputError.audioEngineError
            }
            
            print("🎤 Installing tap on input node...")
            // Install tap on input node
            inputNode?.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
                self?.processAudioBuffer(buffer, isRealTime: true)
            }
            
            print("🎤 Starting audio engine...")
            try audioEngine.start()
            
            DispatchQueue.main.async {
                self.currentSource = .microphone
                self.isProcessing = true
                self.errorMessage = nil
            }
            
            print("✅ Microphone input started successfully")
            
        } catch let error as AudioInputError {
            let errorMessage: String
            switch error {
            case .microphoneAccessDenied:
                errorMessage = "Microphone access denied. Please enable in System Preferences > Security & Privacy > Microphone."
            case .audioEngineError:
                errorMessage = "Audio engine configuration error."
            default:
                errorMessage = "Failed to start microphone: \(error.localizedDescription)"
            }
            
            DispatchQueue.main.async {
                self.errorMessage = errorMessage
                self.currentSource = .none
                self.isProcessing = false
            }
            print("❌ Microphone input error: \(errorMessage)")
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start microphone: \(error.localizedDescription)"
                self.currentSource = .none
                self.isProcessing = false
            }
            print("❌ Microphone input error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - File Input
    
    func processAudioFile(_ fileURL: URL) {
        stopAllInputs()
        
        DispatchQueue.main.async {
            self.currentSource = .file(fileURL)
            self.isProcessing = true
            self.downloadProgress = 0.0
            self.errorMessage = nil
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Check if file exists
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    throw AudioInputError.fileNotFound
                }
                
                // Load audio file
                let audioFile = try AVAudioFile(forReading: fileURL)
                
                // Process file in chunks for real-time analysis
                self.processAudioFileInChunks(audioFile)
                
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to process file: \(error.localizedDescription)"
                    self.isProcessing = false
                    self.currentSource = .none
                }
            }
        }
    }
    
    private func processAudioFileInChunks(_ audioFile: AVAudioFile) {
        let frameCapacity = AVAudioFrameCount(bufferSize)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCapacity) else {
            return
        }
        
        let totalFrames = audioFile.length
        var currentFrame: AVAudioFramePosition = 0
        
        while currentFrame < totalFrames {
            do {
                try audioFile.read(into: buffer)
                
                if buffer.frameLength > 0 {
                    self.processAudioBuffer(buffer, isRealTime: false)
                    
                    // Update progress
                    currentFrame += AVAudioFramePosition(buffer.frameLength)
                    let progress = Double(currentFrame) / Double(totalFrames)
                    
                    DispatchQueue.main.async {
                        self.downloadProgress = progress
                    }
                    
                    // Simulate real-time processing speed
                    let duration = Double(buffer.frameLength) / audioFile.processingFormat.sampleRate
                    Thread.sleep(forTimeInterval: duration * 0.1) // 10x speed
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error reading audio file: \(error.localizedDescription)"
                }
                break
            }
        }
        
        DispatchQueue.main.async {
            self.isProcessing = false
            self.downloadProgress = 1.0
        }
    }
    
    // MARK: - URL Input
    
    func processAudioFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL format"
            }
            return
        }
        
        stopAllInputs()
        
        DispatchQueue.main.async {
            self.currentSource = .url(url)
            self.isProcessing = true
            self.downloadProgress = 0.0
            self.errorMessage = nil
        }
        
        // Download and process URL
        downloadAndProcessAudio(from: url)
    }
    
    private func downloadAndProcessAudio(from url: URL) {
        let session = URLSession.shared
        
        let downloadTask = session.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Download failed: \(error.localizedDescription)"
                    self.isProcessing = false
                }
                return
            }
            
            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    self.errorMessage = "Download failed: No data received"
                    self.isProcessing = false
                }
                return
            }
            
            // Process the downloaded file
            self.processAudioFile(tempURL)
        }
        
        // Track download progress
        let progressObserver = downloadTask.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.downloadProgress = progress.fractionCompleted * 0.5 // First 50% is download
            }
        }
        
        downloadTask.resume()
    }
    
    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, isRealTime: Bool) {
        guard let floatChannelData = buffer.floatChannelData else { 
            print("⚠️ No float channel data in audio buffer")
            return 
        }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        print("🔊 Processing audio buffer: \(frameLength) frames, \(channelCount) channels")
        
        // Calculate audio level (RMS)
        var sum: Float = 0.0
        for frame in 0..<frameLength {
            let sample = floatChannelData[0][frame]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        
        DispatchQueue.main.async {
            self.audioLevel = min(rms * 10, 1.0) // Scale and clamp
            print("📊 Audio level: \(self.audioLevel)")
        }
        
        // Create audio buffer for analysis
        let audioBuffer = AudioBuffer(
            data: Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameLength)),
            sampleRate: buffer.format.sampleRate,
            channels: channelCount,
            timestamp: Date()
        )
        
        print("📦 Sending audio buffer to analysis engine")
        // Send to analysis engine
        onAudioData?(audioBuffer)
        
        // For file processing, also analyze immediately
        if !isRealTime {
            analyzeAudioBuffer(audioBuffer)
        }
    }
    
    private func analyzeAudioBuffer(_ buffer: AudioBuffer) {
        // Create temporary file for analysis
        let tempURL = createTemporaryAudioFile(from: buffer.data, sampleRate: buffer.sampleRate)
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = AudioAnalyzer.shared.analyzeAudioFile(tempURL.path)
            
            DispatchQueue.main.async {
                self.onAnalysisComplete?(result)
            }
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
    
    private func createTemporaryAudioFile(from audioData: [Float], sampleRate: Double) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("tmp_rovodev_audio_\(UUID().uuidString).wav")
        
        // Simple WAV file creation (placeholder - you'd use proper audio file writing)
        let data = audioData.withUnsafeBufferPointer { buffer in
            Data(buffer: UnsafeBufferPointer(start: buffer.baseAddress?.withMemoryRebound(to: UInt8.self, capacity: buffer.count * 4) { $0 }, count: buffer.count * 4))
        }
        
        try? data.write(to: tempURL)
        return tempURL
    }
    
    // MARK: - Control Methods
    
    func stopAllInputs() {
        print("⏹ Stopping all inputs...")
        // Stop microphone
        if audioEngine.isRunning {
            print("⏹ Stopping audio engine...")
            audioEngine.stop()
            inputNode?.removeTap(onBus: 0)
            print("⏹ Audio engine stopped")
        }
        
        // Stop audio player
        if let player = audioPlayer {
            print("⏹ Stopping audio player...")
            player.stop()
            audioPlayer = nil
            print("⏹ Audio player stopped")
        }
        
        audioFile = nil
        
        DispatchQueue.main.async {
            self.isProcessing = false
            self.audioLevel = 0.0
            self.downloadProgress = 0.0
        }
        print("⏹ All inputs stopped")
    }
    
    func pauseProcessing() {
        if case .microphone = currentSource {
            audioEngine.pause()
        } else {
            audioPlayer?.pause()
        }
        
        DispatchQueue.main.async {
            self.isProcessing = false
        }
    }
    
    func resumeProcessing() {
        if case .microphone = currentSource {
            try? audioEngine.start()
        } else {
            audioPlayer?.play()
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
        }
    }
    
    // MARK: - Utility Methods
    
    func getSupportedFormats() -> [String] {
        return ["mp3", "wav", "m4a", "aac", "flac", "ogg"]
    }
    
    func isURLValid(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
    
    func getInputSourceDescription() -> String {
        switch currentSource {
        case .microphone:
            return "Live Microphone Input"
        case .file(let url):
            return "File: \(url.lastPathComponent)"
        case .url(let url):
            return "URL: \(url.absoluteString)"
        case .none:
            return "No Input Source"
        }
    }
}