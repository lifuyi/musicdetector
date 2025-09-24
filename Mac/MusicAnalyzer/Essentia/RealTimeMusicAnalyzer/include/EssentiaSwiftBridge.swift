//
//  EssentiaSwiftBridge.swift
//  Swift 友好的 Essentia 包装器
//

import Foundation

/// Swift 音频分析结果
public struct AudioAnalysisResult {
    public let bpm: Float
    public let key: String
    public let scale: String
    public let confidence: Float
    public let isValid: Bool
    
    public init(bpm: Float, key: String, scale: String, confidence: Float) {
        self.bpm = bpm
        self.key = key
        self.scale = scale
        self.confidence = max(0.0, min(1.0, confidence))
        self.isValid = confidence > 0.1
    }
    
    public var description: String {
        return "BPM: \(String(format: "%.1f", bpm)), Key: \(key) \(scale), Confidence: \(String(format: "%.2f", confidence))"
    }
}

/// Swift 音频分析器
public class AudioAnalyzer {
    
    // 单例模式
    public static let shared = AudioAnalyzer()
    
    private let analyzer: EssentiaIOSAnalyzer
    
    private init() {
        self.analyzer = EssentiaIOSAnalyzer.shared()
    }
    
    /// 是否可用
    public var isAvailable: Bool {
        return analyzer.isAvailable
    }
    
    /// 版本信息
    public var version: String {
        return analyzer.version
    }
    
    /// 分析音频文件
    public func analyzeAudioFile(_ filePath: String) -> AudioAnalysisResult? {
        guard let result = analyzer.analyzeAudioFile(filePath) else {
            return nil
        }
        
        // Ensure confidence is within valid range
        let confidence = max(0.0, min(1.0, result.confidence))
        
        return AudioAnalysisResult(
            bpm: result.bpm,
            key: result.key,
            scale: result.scale,
            confidence: confidence
        )
    }
    
    /// 分析音频文件 (异步)
    public func analyzeAudioFileAsync(_ filePath: String, completion: @escaping (AudioAnalysisResult?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.analyzeAudioFile(filePath)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    /// 分析音频文件 (URL)
    public func analyzeAudioFile(at url: URL) -> AudioAnalysisResult? {
        return analyzeAudioFile(url.path)
    }
    
    /// 分析音频文件 (URL, 异步)
    public func analyzeAudioFileAsync(at url: URL, completion: @escaping (AudioAnalysisResult?) -> Void) {
        analyzeAudioFileAsync(url.path, completion: completion)
    }
    
    /// 检测 BPM
    public func detectBPM(from filePath: String) -> Float {
        return analyzer.detectBPM(fromAudioFile: filePath)
    }
    
    /// 检测调性
    public func detectKey(from filePath: String) -> String {
        return analyzer.detectKey(fromAudioFile: filePath)
    }
    
    /// 批量分析
    public func analyzeMultipleFiles(_ filePaths: [String]) -> [AudioAnalysisResult] {
        let results = analyzer.analyzeMultipleFiles(filePaths)
        return results.compactMap { result in
            guard let essentiaResult = result as? EssentiaAnalysisResult else { return nil }
            return AudioAnalysisResult(
                bpm: essentiaResult.bpm,
                key: essentiaResult.key,
                scale: essentiaResult.scale,
                confidence: essentiaResult.confidence
            )
        }
    }
    
    /// 支持的音频格式
    public static var supportedFormats: [String] {
        return EssentiaIOSAnalyzer.supportedAudioFormats()
    }
    
    /// 检查文件是否支持
    public static func isAudioFileSupported(_ filePath: String) -> Bool {
        return EssentiaIOSAnalyzer.isAudioFileSupported(filePath)
    }
}

/// 音频分析错误
public enum AudioAnalyzerError: Error {
    case notAvailable
    case fileNotFound
    case unsupportedFormat
    case analysisFailed
    case unknownError
}

/// 便捷扩展
extension AudioAnalyzer {
    
    /// 分析结果扩展
    public func analyzeWithDetails(_ filePath: String) -> (result: AudioAnalysisResult?, error: Error?) {
        let essentiaResult = analyzer.analyzeAudioFile(filePath)
        
        guard let result = essentiaResult else {
            return (nil, AudioAnalyzerError.unknownError)
        }
        
        let swiftResult = AudioAnalysisResult(
            bpm: result.bpm,
            key: result.key,
            scale: result.scale,
            confidence: result.confidence
        )
        
        return (swiftResult, nil)
    }
}
