/*
 EssentiaAPIClient.swift
 
 Essentia API 客户端，用于与 Python 后端通信
 提供高精度的音频分析功能
 macOS 版本
 */

import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - 数据模型

struct EssentiaAnalysisResult: Codable {
    let rhythmAnalysis: RhythmAnalysis
    let keyAnalysis: KeyAnalysis
    let analysisEngine: String
    let overallQuality: Double
    let recommendedUse: String
    let processingTime: Double?
    let fileInfo: FileInfo?
    
    enum CodingKeys: String, CodingKey {
        case rhythmAnalysis = "rhythm_analysis"
        case keyAnalysis = "key_analysis"
        case analysisEngine = "analysis_engine"
        case overallQuality = "overall_quality"
        case recommendedUse = "recommended_use"
        case processingTime = "processing_time"
        case fileInfo = "file_info"
    }
    
    struct RhythmAnalysis: Codable {
        let bpm: Double
        let bpmRaw: Double
        let beats: [Double]
        let confidence: Double
        let beatPositions: [Double]
        let beatIntervals: [Double]
        let degaraBeats: [Double]
        let beatLoudness: [Double]
        let onsetRate: Double
        let audioDuration: Double
        let qualityScore: Double
        
        enum CodingKeys: String, CodingKey {
            case bpm, beats, confidence
            case bpmRaw = "bpm_raw"
            case beatPositions = "beat_positions"
            case beatIntervals = "beat_intervals" 
            case degaraBeats = "degara_beats"
            case beatLoudness = "beat_loudness"
            case onsetRate = "onset_rate"
            case audioDuration = "audio_duration"
            case qualityScore = "quality_score"
        }
    }
    
    struct KeyAnalysis: Codable {
        let key: String
        let scale: String
        let strength: Double
        let algorithm: String
        let alternatives: [String: KeyAlternative]
        let stabilityScore: Double
        let confidenceLevel: String
        
        enum CodingKeys: String, CodingKey {
            case key, scale, strength, algorithm, alternatives
            case stabilityScore = "stability_score"
            case confidenceLevel = "confidence_level"
        }
        
        struct KeyAlternative: Codable {
            let key: String
            let scale: String
            let strength: Double
        }
    }
    
    struct FileInfo: Codable {
        let originalFilename: String
        let fileSize: Int
        let tempId: String
        
        enum CodingKeys: String, CodingKey {
            case originalFilename = "original_filename"
            case fileSize = "file_size"
            case tempId = "temp_id"
        }
    }
}

struct EssentiaStatus: Codable {
    let essentiaAvailable: Bool
    let version: String
    let supportedFormats: [String]
    let features: [String]
    
    enum CodingKeys: String, CodingKey {
        case essentiaAvailable = "essentia_available"
        case version
        case supportedFormats = "supported_formats"
        case features
    }
}

// MARK: - API 客户端

class EssentiaAPIClient {
    
    // MARK: - 配置
    
    private let baseURL: String
    private let session: URLSession
    private let timeout: TimeInterval = 30.0
    
    // 单例模式
    static let shared = EssentiaAPIClient()
    
    // MARK: - 初始化
    
    init(baseURL: String = "http://localhost:10814") {
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - 公共方法
    
    /// 检查 Essentia 服务状态
    func checkStatus() async throws -> EssentiaStatus {
        let url = URL(string: "\(baseURL)/essentia-status")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError("服务不可用")
        }
        
        return try JSONDecoder().decode(EssentiaStatus.self, from: data)
    }
    
    /// 使用 Essentia 分析音频文件
    func analyzeAudio(fileURL: URL) async throws -> EssentiaAnalysisResult {
        print("🔧 开始 Essentia 分析: \(fileURL.lastPathComponent)")
        
        let url = URL(string: "\(baseURL)/analyze-essentia")!
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 读取音频数据
        let audioData = try Data(contentsOf: fileURL)
        print("📊 音频文件大小: \(audioData.count / 1024)KB")
        
        let httpBody = createMultipartBody(
            boundary: boundary,
            audioData: audioData,
            filename: fileURL.lastPathComponent
        )
        
        // 发送请求
        let startTime = Date()
        let (data, response) = try await session.upload(for: request, from: httpBody)
        let processingTime = Date().timeIntervalSince(startTime)
        
        print("⏱️ 网络请求耗时: \(String(format: "%.2f", processingTime))秒")
        
        // 检查响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("无效响应")
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            throw APIError.serverError("服务器错误 (\(httpResponse.statusCode)): \(errorMessage)")
        }
        
        // 解析结果
        do {
            let result = try JSONDecoder().decode(EssentiaAnalysisResult.self, from: data)
            print("✅ Essentia 分析完成 - BPM: \(result.rhythmAnalysis.bpm), 调性: \(result.keyAnalysis.key) \(result.keyAnalysis.scale)")
            return result
        } catch {
            print("❌ JSON 解析错误: \(error)")
            print("📄 响应数据: \(String(data: data, encoding: .utf8) ?? "无法解码")")
            throw APIError.parseError("结果解析失败: \(error.localizedDescription)")
        }
    }
    
    /// 混合分析（Essentia + 传统算法）
    func hybridAnalysis(fileURL: URL) async throws -> HybridAnalysisResult {
        let url = URL(string: "\(baseURL)/analyze-hybrid")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let audioData = try Data(contentsOf: fileURL)
        let httpBody = createMultipartBody(
            boundary: boundary,
            audioData: audioData,
            filename: fileURL.lastPathComponent
        )
        
        let (data, response) = try await session.upload(for: request, from: httpBody)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError("混合分析请求失败")
        }
        
        return try JSONDecoder().decode(HybridAnalysisResult.self, from: data)
    }
    
    // MARK: - macOS 特定功能
    
    /// 从用户选择的文件进行分析
    func analyzeFromFilePicker() async throws -> EssentiaAnalysisResult? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [
                    .mp3, .wav, .aiff, .mpeg4Audio,
                    UTType(filenameExtension: "flac") ?? .audio
                ]
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                
                if panel.runModal() == .OK, let fileURL = panel.url {
                    Task {
                        do {
                            let result = try await self.analyzeAudio(fileURL: fileURL)
                            continuation.resume(returning: result)
                        } catch {
                            print("文件分析失败: \(error)")
                            continuation.resume(returning: nil)
                        }
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func createMultipartBody(boundary: String, audioData: Data, filename: String) -> Data {
        var body = Data()
        
        // 文件部分
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        
        // 根据文件扩展名设置 MIME 类型
        let mimeType = getMimeType(for: filename)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    private func getMimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "flac":
            return "audio/flac"
        case "m4a":
            return "audio/mp4"
        case "aac":
            return "audio/aac"
        case "aiff":
            return "audio/aiff"
        default:
            return "audio/mpeg"
        }
    }
}

// MARK: - 混合分析结果（与 iOS 版本相同）

struct HybridAnalysisResult: Codable {
    let results: AnalysisResults
    let comparison: AnalysisComparison
    let fileInfo: EssentiaAnalysisResult.FileInfo
    
    enum CodingKeys: String, CodingKey {
        case results, comparison
        case fileInfo = "file_info"
    }
    
    struct AnalysisResults: Codable {
        let essentia: EssentiaAnalysisResult?
        let traditional: TraditionalAnalysisResult?
    }
    
    struct TraditionalAnalysisResult: Codable {
        let rhythmAnalysis: TraditionalRhythm
        let chordProgression: [ChordSegment]
        let analysisEngine: String
        
        enum CodingKeys: String, CodingKey {
            case rhythmAnalysis = "rhythm_analysis"
            case chordProgression = "chord_progression"
            case analysisEngine = "analysis_engine"
        }
        
        struct TraditionalRhythm: Codable {
            let tempo: Double
            let beats: [Int]
            let beatTimes: [Double]
            let measureStarts: [Double]
            let averageBeatInterval: Double
            
            enum CodingKeys: String, CodingKey {
                case tempo, beats
                case beatTimes = "beat_times"
                case measureStarts = "measure_starts" 
                case averageBeatInterval = "average_beat_interval"
            }
        }
        
        struct ChordSegment: Codable {
            let time: Double
            let chord: String
            let notes: [String]
        }
    }
    
    struct AnalysisComparison: Codable {
        let bpmComparison: BPMComparison
        let keyComparison: [String: String]
        let recommendation: String
        
        enum CodingKeys: String, CodingKey {
            case bpmComparison = "bpm_comparison"
            case keyComparison = "key_comparison"
            case recommendation
        }
        
        struct BPMComparison: Codable {
            let essentiaBpm: Double?
            let traditionalBpm: Double?
            let difference: Double?
            let agreement: String?
            
            enum CodingKeys: String, CodingKey {
                case essentiaBpm = "essentia_bpm"
                case traditionalBpm = "traditional_bpm"
                case difference, agreement
            }
        }
    }
}

// MARK: - 错误定义

enum APIError: Error, LocalizedError {
    case networkError(String)
    case serverError(String)
    case parseError(String)
    case fileError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "网络错误: \(message)"
        case .serverError(let message):
            return "服务器错误: \(message)"
        case .parseError(let message):
            return "解析错误: \(message)"
        case .fileError(let message):
            return "文件错误: \(message)"
        }
    }
}

// MARK: - 扩展：便捷方法

extension EssentiaAPIClient {
    
    /// 快速检查服务是否可用
    func isServiceAvailable() async -> Bool {
        do {
            let status = try await checkStatus()
            return status.essentiaAvailable
        } catch {
            print("⚠️ Essentia 服务检查失败: \(error)")
            return false
        }
    }
    
    /// 获取支持的文件格式
    func getSupportedFormats() async -> [String] {
        do {
            let status = try await checkStatus()
            return status.supportedFormats
        } catch {
            return ["mp3", "wav", "m4a", "aiff"] // macOS 默认格式
        }
    }
    
    /// 检查文件是否支持
    func isFileSupported(_ fileURL: URL) -> Bool {
        let ext = fileURL.pathExtension.lowercased()
        return ["mp3", "wav", "flac", "m4a", "aac", "aiff"].contains(ext)
    }
}

// MARK: - NSOpenPanel 扩展

extension NSOpenPanel {
    static func selectAudioFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .mp3, .wav, .aiff, .mpeg4Audio,
            UTType(filenameExtension: "flac") ?? .audio
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "选择音频文件"
        panel.message = "请选择要分析的音频文件"
        
        return panel.runModal() == .OK ? panel.url : nil
    }
}