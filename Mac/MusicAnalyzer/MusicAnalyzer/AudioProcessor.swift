import AVFoundation
import Accelerate

class AudioProcessor {
    
    // FFT 参数 - 增加分辨率提高准确性
    private let fftSize: Int = 2048  // 从4096降低到2048，更快响应
    private let hopSize: Int = 512   // 从1024降低到512，更快更新
    private let sampleRate: Double = 44100
    
    // FFT 设置
    private var fftSetup: FFTSetup
    private var log2n: vDSP_Length
    private var window: [Float]
    
    // 缓冲区
    private var audioBuffer: [Float] = []
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var complexBuffer: DSPSplitComplex
    
    init() {
        self.log2n = vDSP_Length(log2(Float(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))!
        
        // 创建汉宁窗
        self.window = Array(repeating: 0.0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        
        // 初始化缓冲区
        self.realBuffer = Array(repeating: 0.0, count: fftSize/2)
        self.imagBuffer = Array(repeating: 0.0, count: fftSize/2)
        self.complexBuffer = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    // MARK: - 音频缓冲区处理
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) -> AudioFeatures? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        let frameCount = Int(buffer.frameLength)
        
        // 添加新数据到缓冲区
        let newSamples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        audioBuffer.append(contentsOf: newSamples)
        
        // 如果缓冲区足够大，进行分析
        if audioBuffer.count >= fftSize {
            let features = extractFeatures(from: Array(audioBuffer.prefix(fftSize)))
            
            // 移除已处理的数据（保留重叠部分）- 修复边界计算
            let remainingAfterProcess = audioBuffer.count - fftSize
            let removeCount = min(hopSize, remainingAfterProcess + hopSize)
            audioBuffer.removeFirst(min(removeCount, audioBuffer.count))
            
            return features
        }
        
        return nil
    }
    
    // MARK: - 特征提取
    private func extractFeatures(from samples: [Float]) -> AudioFeatures {
        // 应用窗函数
        var windowedSamples = Array(repeating: Float(0.0), count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))
        
        // 执行FFT
        let magnitudes = performFFT(windowedSamples)
        
        // 提取各种特征
        let chromaVector = extractChromaFeatures(from: magnitudes)
        let spectralCentroid = calculateSpectralCentroid(magnitudes)
        let spectralRolloff = calculateSpectralRolloff(magnitudes)
        let mfcc = extractMFCC(from: magnitudes)
        let tonnetz = calculateTonnetz(from: chromaVector)
        
        return AudioFeatures(
            chroma: chromaVector,
            spectralCentroid: spectralCentroid,
            spectralRolloff: spectralRolloff,
            mfcc: mfcc,
            tonnetz: tonnetz,
            magnitude: magnitudes,
            timestamp: Date()
        )
    }
    
    // MARK: - FFT计算
    private func performFFT(_ samples: [Float]) -> [Float] {
        var input = samples
        
        // 转换为复数格式
        input.withUnsafeMutableBufferPointer { inputPtr in
            inputPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize/2) { complexInput in
                vDSP_ctoz(complexInput, 2, &complexBuffer, 1, vDSP_Length(fftSize/2))
            }
        }
        
        // 执行FFT
        vDSP_fft_zrip(fftSetup, &complexBuffer, 1, log2n, Int32(FFT_FORWARD))
        
        // 计算幅度谱
        var magnitudes = Array(repeating: Float(0.0), count: fftSize/2)
        vDSP_zvmags(&complexBuffer, 1, &magnitudes, 1, vDSP_Length(fftSize/2))
        
        // 转换为dB
        var logMagnitudes = Array(repeating: Float(0.0), count: fftSize/2)
        var one: Float = 1.0
        vvlog10f(&logMagnitudes, magnitudes, [Int32(fftSize/2)])
        vDSP_vsmul(logMagnitudes, 1, &one, &logMagnitudes, 1, vDSP_Length(fftSize/2))
        
        return logMagnitudes
    }
    
    // MARK: - 色彩特征提取 - 改进版本
    private func extractChromaFeatures(from magnitudes: [Float]) -> [Float] {
        let chromaBins = 12
        var chroma = Array(repeating: Float(0.0), count: chromaBins)
        
        // 使用对数频率映射和加权，提高低频精度
        for i in 1..<magnitudes.count {
            let frequency = Float(i) * Float(sampleRate) / Float(fftSize)
            
            // 扩展频率范围，加强基频检测
            if frequency > 65 && frequency < 8000 {
                let pitch = frequencyToPitchClass(frequency)
                
                // 根据频率给予不同权重，强调基频和低次谐波
                let octave = log2(frequency / 65.0) / 12.0
                let weight: Float
                if octave < 1.0 {
                    weight = 2.0 // 基频区域权重最高
                } else if octave < 2.0 {
                    weight = 1.5 // 第一泛音区域
                } else if octave < 3.0 {
                    weight = 1.0 // 第二泛音区域
                } else {
                    weight = 0.6 // 高频区域权重降低
                }
                
                chroma[pitch] += magnitudes[i] * weight
            }
        }
        
        // 改进的归一化：使用平方根压缩，保持动态范围
        let maxVal = chroma.max() ?? 0
        if maxVal > 0 {
            for i in 0..<chromaBins {
                chroma[i] = sqrt(chroma[i] / maxVal)
            }
        }
        
        // 再次归一化
        let sum = chroma.reduce(0, +)
        if sum > 0 {
            for i in 0..<chromaBins {
                chroma[i] /= sum
            }
        }
        
        return chroma
    }
    
    private func frequencyToPitchClass(_ frequency: Float) -> Int {
        let a4 = Float(440.0) // A4参考频率
        
        if frequency <= 0 { return 0 }
        
        // 更精确的音高计算，以C为0
        let pitchNumber = 12 * log2(frequency / a4) + 9 // A4是第9个半音（从C开始）
        let pitchClass = Int(pitchNumber.rounded()) % 12
        return (pitchClass + 12) % 12 // 确保正数
    }
    
    // MARK: - 其他特征计算
    private func calculateSpectralCentroid(_ magnitudes: [Float]) -> Float {
        var weightedSum: Float = 0
        var totalMagnitude: Float = 0
        
        for i in 0..<magnitudes.count {
            let frequency = Float(i) * Float(sampleRate) / Float(fftSize)
            weightedSum += frequency * magnitudes[i]
            totalMagnitude += magnitudes[i]
        }
        
        return totalMagnitude > 0 ? weightedSum / totalMagnitude : 0
    }
    
    private func calculateSpectralRolloff(_ magnitudes: [Float]) -> Float {
        let totalEnergy = magnitudes.reduce(0, +)
        let threshold = totalEnergy * 0.85
        
        var cumulativeEnergy: Float = 0
        for i in 0..<magnitudes.count {
            cumulativeEnergy += magnitudes[i]
            if cumulativeEnergy >= threshold {
                return Float(i) * Float(sampleRate) / Float(fftSize)
            }
        }
        
        return Float(magnitudes.count - 1) * Float(sampleRate) / Float(fftSize)
    }
    
    private func extractMFCC(from magnitudes: [Float]) -> [Float] {
        // 简化的MFCC实现，实际应用中可能需要更完整的梅尔滤波器组
        let mfccCount = 13
        var mfcc = Array(repeating: Float(0.0), count: mfccCount)
        
        // 这里是一个简化版本，实际实现需要完整的梅尔滤波器组和DCT
        for i in 0..<min(mfccCount, magnitudes.count) {
            mfcc[i] = magnitudes[i]
        }
        
        return mfcc
    }
    
    private func calculateTonnetz(from chroma: [Float]) -> [Float] {
        // Tonnetz特征：基于音程关系的空间表示
        var tonnetz = Array(repeating: Float(0.0), count: 6)
        
        // 五度圆和大三度圆的坐标
        let fifthsX = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5].map { cos(Float($0) * 2 * .pi / 12) }
        let fifthsY = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5].map { sin(Float($0) * 2 * .pi / 12) }
        
        let majorThirdX = [0, 4, 8, 0, 4, 8, 0, 4, 8, 0, 4, 8].map { cos(Float($0) * 2 * .pi / 12) }
        let majorThirdY = [0, 4, 8, 0, 4, 8, 0, 4, 8, 0, 4, 8].map { sin(Float($0) * 2 * .pi / 12) }
        
        for i in 0..<12 {
            tonnetz[0] += chroma[i] * fifthsX[i]
            tonnetz[1] += chroma[i] * fifthsY[i]
            tonnetz[2] += chroma[i] * majorThirdX[i]
            tonnetz[3] += chroma[i] * majorThirdY[i]
        }
        
        return tonnetz
    }
}

// MARK: - 音频特征数据结构
struct AudioFeatures {
    let chroma: [Float]
    let spectralCentroid: Float
    let spectralRolloff: Float
    let mfcc: [Float]
    let tonnetz: [Float]
    let magnitude: [Float]
    let timestamp: Date
}