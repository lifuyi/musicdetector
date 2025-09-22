import AVFoundation
import Accelerate

protocol AudioInputDelegate: AnyObject {
    func didReceiveAudioBuffer(_ buffer: AVAudioPCMBuffer)
    func didEncounterError(_ error: Error)
}

class AudioInputManager: NSObject {
    weak var delegate: AudioInputDelegate?
    
    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode
    private var audioFormat: AVAudioFormat
    
    // 音频参数
    private let sampleRate: Double = 44100
    private let bufferSize: AVAudioFrameCount = 1024
    
    override init() {
        self.audioEngine = AVAudioEngine()
        self.inputNode = audioEngine.inputNode
        self.audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        super.init()
    }
    
    // MARK: - 麦克风录制
    func startMicrophoneInput() throws {
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        try audioEngine.start()
    }
    
    func stopMicrophoneInput() {
        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }
    
    // MARK: - 文件播放
    func playAudioFile(url: URL) throws {
        let audioFile = try AVAudioFile(forReading: url)
        let audioPlayerNode = AVAudioPlayerNode()
        
        audioEngine.attach(audioPlayerNode)
        audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
        
        // 安装tap来捕获播放的音频
        audioPlayerNode.installTap(onBus: 0, bufferSize: bufferSize, format: audioFile.processingFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        try audioEngine.start()
        audioPlayerNode.scheduleFile(audioFile, at: nil)
        audioPlayerNode.play()
    }
    
    // MARK: - URL流播放
    func playAudioFromURL(_ url: URL) {
        // 使用AVPlayer来处理URL流
        let player = AVPlayer(url: url)
        
        // 这里需要添加从AVPlayer捕获音频的逻辑
        // 可以使用AVPlayerItemVideoOutput和MetalPerformanceShaders
        // 或者考虑使用第三方库如StreamingKit
    }
    
    // MARK: - 音频处理
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        
        // 转换为单声道如果需要
        let monoBuffer = convertToMono(buffer)
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didReceiveAudioBuffer(monoBuffer)
        }
    }
    
    private func convertToMono(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: buffer.format.sampleRate, channels: 1),
              let monoBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: buffer.frameCapacity) else {
            return buffer
        }
        
        monoBuffer.frameLength = buffer.frameLength
        
        if buffer.format.channelCount == 1 {
            // 已经是单声道
            memcpy(monoBuffer.floatChannelData![0], buffer.floatChannelData![0], Int(buffer.frameLength) * MemoryLayout<Float>.size)
        } else if buffer.format.channelCount == 2 {
            // 立体声转单声道
            let leftChannel = buffer.floatChannelData![0]
            let rightChannel = buffer.floatChannelData![1]
            let monoChannel = monoBuffer.floatChannelData![0]
            
            for i in 0..<Int(buffer.frameLength) {
                monoChannel[i] = (leftChannel[i] + rightChannel[i]) * 0.5
            }
        }
        
        return monoBuffer
    }
}