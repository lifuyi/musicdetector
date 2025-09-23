//
//  RealTimeAudioCapture.swift
//  Real-time audio capture for macOS
//

import AVFoundation
import Combine

class RealTimeAudioCapture: NSObject, ObservableObject {
    @Published var audioLevel: Float = 0.0
    @Published var isCapturing = false
    @Published var selectedDevice: AVCaptureDevice?
    
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioBuffer: AVAudioPCMBuffer?
    private let bufferSize: AVAudioFrameCount = 4096
    
    var onAudioData: ((AudioBuffer) -> Void)?
    
    override init() {
        super.init()
        setupAudioSession()
        setupAudioEngine()
    }
    
    private func setupAudioSession() {
        // Request microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if !granted {
                    print("Microphone access denied")
                }
            }
        }
    }
    
    private func setupAudioEngine() {
        inputNode = audioEngine.inputNode
        let inputFormat = inputNode?.outputFormat(forBus: 0)
        
        guard let format = inputFormat else {
            print("Failed to get input format")
            return
        }
        
        // Install tap on input node
        inputNode?.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
    }
    
    func startCapture() {
        guard !audioEngine.isRunning else { return }
        
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isCapturing = true
            }
            print("Audio capture started")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func stopCapture() {
        guard audioEngine.isRunning else { return }
        
        audioEngine.stop()
        inputNode?.removeTap(onBus: 0)
        
        DispatchQueue.main.async {
            self.isCapturing = false
            self.audioLevel = 0.0
        }
        print("Audio capture stopped")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let floatChannelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // Calculate audio level (RMS)
        var sum: Float = 0.0
        for frame in 0..<frameLength {
            let sample = floatChannelData[0][frame]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        
        DispatchQueue.main.async {
            self.audioLevel = min(rms * 10, 1.0) // Scale and clamp
        }
        
        // Create audio buffer for analysis
        let audioBuffer = AudioBuffer(
            data: Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameLength)),
            sampleRate: buffer.format.sampleRate,
            channels: channelCount,
            timestamp: Date()
        )
        
        onAudioData?(audioBuffer)
    }
    
    // Get available audio input devices
    func getAvailableDevices() -> [AVCaptureDevice] {
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        ).devices
    }
}

// Audio buffer structure for analysis
struct AudioBuffer {
    let data: [Float]
    let sampleRate: Double
    let channels: Int
    let timestamp: Date
    
    var duration: TimeInterval {
        return Double(data.count) / sampleRate
    }
}