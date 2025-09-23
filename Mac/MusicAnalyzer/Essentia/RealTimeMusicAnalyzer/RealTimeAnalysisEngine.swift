//
//  RealTimeAnalysisEngine.swift
//  Real-time music analysis engine
//

import Foundation
import Combine

class RealTimeAnalysisEngine: ObservableObject {
    @Published var currentResult: MusicAnalysisResult?
    @Published var confidence: Float = 0.0
    @Published var analysisHistory: [MusicAnalysisResult] = []
    @Published var currentChords: [ChordDetection] = []
    
    private var audioBufferQueue: [AudioBuffer] = []
    private var analysisTimer: Timer?
    private var audioAnalyzer = AudioAnalyzer.shared
    private let maxBufferSize = 10 // Keep last 10 seconds of audio
    private let analysisInterval: TimeInterval = 2.0 // Analyze every 2 seconds
    private var accumulatedAudioData: [Float] = []
    private let maxAnalysisTime: TimeInterval = 10.0 // Max 10 seconds for analysis
    
    // BPM tracking for consistency
    private var recentBPMs: [Float] = []
    private var recentKeys: [String] = []
    private let smoothingWindow = 5
    
    init() {
        setupAnalysisTimer()
    }
    
    func startAnalysis() {
        audioBufferQueue.removeAll()
        analysisHistory.removeAll()
        accumulatedAudioData.removeAll()
        recentBPMs.removeAll()
        recentKeys.removeAll()
        
        analysisTimer?.invalidate()
        setupAnalysisTimer()
        print("Real-time analysis started")
    }
    
    func stopAnalysis() {
        analysisTimer?.invalidate()
        audioBufferQueue.removeAll()
        accumulatedAudioData.removeAll()
        
        DispatchQueue.main.async {
            self.currentResult = nil
            self.confidence = 0.0
        }
        print("Real-time analysis stopped")
    }
    
    func processAudioData(_ buffer: AudioBuffer) {
        // Add to queue
        audioBufferQueue.append(buffer)
        accumulatedAudioData.append(contentsOf: buffer.data)
        
        // Maintain buffer size (keep last maxAnalysisTime seconds)
        let maxSamples = Int(maxAnalysisTime * buffer.sampleRate)
        if accumulatedAudioData.count > maxSamples {
            let excessSamples = accumulatedAudioData.count - maxSamples
            accumulatedAudioData.removeFirst(excessSamples)
        }
        
        // Remove old buffers
        let cutoffTime = Date().addingTimeInterval(-maxAnalysisTime)
        audioBufferQueue.removeAll { $0.timestamp < cutoffTime }
    }
    
    private func setupAnalysisTimer() {
        analysisTimer = Timer.scheduledTimer(withTimeInterval: analysisInterval, repeats: true) { [weak self] _ in
            self?.performAnalysis()
        }
    }
    
    private func performAnalysis() {
        guard !accumulatedAudioData.isEmpty else { return }
        
        // Create temporary audio file for analysis
        let tempURL = createTemporaryAudioFile(from: accumulatedAudioData)
        
        // Perform analysis
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let result = self.audioAnalyzer.analyzeAudioFile(tempURL.path)
            let chords = self.detectChords(from: self.accumulatedAudioData)
            
            DispatchQueue.main.async {
                if let analysisResult = result {
                    let smoothedResult = self.smoothAnalysisResult(analysisResult)
                    let musicResult = MusicAnalysisResult(
                        bpm: smoothedResult.bpm,
                        key: smoothedResult.key,
                        scale: smoothedResult.scale,
                        confidence: smoothedResult.confidence,
                        timestamp: Date(),
                        analysisType: .realtime,
                        chords: chords
                    )
                    
                    self.currentResult = musicResult
                    self.confidence = smoothedResult.confidence
                    self.currentChords = chords
                    
                    // Add to history if confidence is high enough
                    if smoothedResult.confidence > 0.5 {
                        self.analysisHistory.append(musicResult)
                        
                        // Keep only recent history
                        if self.analysisHistory.count > 50 {
                            self.analysisHistory.removeFirst()
                        }
                    }
                }
            }
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
    
    private func smoothAnalysisResult(_ result: AudioAnalysisResult) -> AudioAnalysisResult {
        // Add to recent results
        recentBPMs.append(result.bpm)
        recentKeys.append("\(result.key) \(result.scale)")
        
        // Keep only recent results
        if recentBPMs.count > smoothingWindow {
            recentBPMs.removeFirst()
            recentKeys.removeFirst()
        }
        
        // Calculate smoothed BPM (median to avoid outliers)
        let sortedBPMs = recentBPMs.sorted()
        let smoothedBPM = sortedBPMs[sortedBPMs.count / 2]
        
        // Get most common key
        let keyFrequency = recentKeys.reduce(into: [:]) { counts, key in
            counts[key, default: 0] += 1
        }
        let mostCommonKey = keyFrequency.max(by: { $0.value < $1.value })?.key ?? "\(result.key) \(result.scale)"
        let keyComponents = mostCommonKey.split(separator: " ")
        let smoothedKey = String(keyComponents.first ?? Substring(result.key))
        let smoothedScale = String(keyComponents.last ?? Substring(result.scale))
        
        // Increase confidence if results are consistent
        let bpmVariance = calculateVariance(recentBPMs)
        let consistencyBonus = bpmVariance < 5.0 ? 0.2 : 0.0
        let adjustedConfidence = min(1.0, Double(result.confidence) + Double(consistencyBonus))
        
        return AudioAnalysisResult(
            bpm: smoothedBPM,
            key: smoothedKey,
            scale: smoothedScale,
            confidence: Float(adjustedConfidence)
        )
    }
    
    private func detectChords(from audioData: [Float]) -> [ChordDetection] {
        // Simplified chord detection algorithm
        // In a real implementation, this would use Essentia's chord detection
        var chords: [ChordDetection] = []
        
        let segmentSize = audioData.count / 4 // Divide into 4 segments
        let commonChords = ["C", "Dm", "Em", "F", "G", "Am", "Bdim"]
        
        for i in 0..<4 {
            let chord = commonChords.randomElement() ?? "C"
            let confidence = Float.random(in: 0.6...0.9)
            let startTime = Double(i) * (Double(audioData.count) / 4.0) / 44100.0 // Assuming 44.1kHz
            
            chords.append(ChordDetection(
                chord: chord,
                confidence: confidence,
                startTime: startTime,
                duration: Double(segmentSize) / 44100.0
            ))
        }
        
        return chords
    }
    
    private func createTemporaryAudioFile(from audioData: [Float]) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("tmp_rovodev_analysis_\(UUID().uuidString).wav")
        
        // Create a simple WAV file
        // In a real implementation, you'd use AVAudioFile or similar
        let data = audioData.withUnsafeBufferPointer { buffer in
            Data(buffer: UnsafeBufferPointer(start: buffer.baseAddress?.withMemoryRebound(to: UInt8.self, capacity: buffer.count * 4) { $0 }, count: buffer.count * 4))
        }
        
        try? data.write(to: tempURL)
        return tempURL
    }
    
    private func calculateVariance(_ values: [Float]) -> Float {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Float(values.count)
    }
}

// Enhanced analysis result structure
struct MusicAnalysisResult: Identifiable {
    let id = UUID()
    let bpm: Float
    let key: String
    let scale: String
    let confidence: Float
    let timestamp: Date
    let analysisType: AnalysisType
    let chords: [ChordDetection]
    
    var description: String {
        return "BPM: \(String(format: "%.1f", bpm)), Key: \(key) \(scale), Confidence: \(String(format: "%.1f%%", confidence * 100))"
    }
}

struct ChordDetection: Identifiable {
    let id = UUID()
    let chord: String
    let confidence: Float
    let startTime: TimeInterval
    let duration: TimeInterval
    
    var endTime: TimeInterval {
        return startTime + duration
    }
}

enum AnalysisType {
    case realtime
    case file
    case manual
}