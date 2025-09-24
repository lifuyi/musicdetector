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
    
    func configure(bufferSize: Int, hopSize: Int, sampleRate: Double) {
        // Configure analysis parameters
        // In a real implementation, this would set up Essentia parameters
        print("Analysis engine configured - Buffer: \(bufferSize), Hop: \(hopSize), Sample Rate: \(sampleRate)")
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
        // Safety check
        guard !buffer.data.isEmpty else { 
            print("⚠️ Skipping empty audio buffer")
            return 
        }
        
        print("🔊 Received audio buffer with \(buffer.data.count) samples at \(buffer.timestamp)")
        
        // Auto-start analysis when we receive audio data
        // This ensures microphone input triggers analysis
        if analysisTimer == nil || !analysisTimer!.isValid {
            print("🔄 Auto-starting analysis engine")
            startAnalysis()
        }
        
        // Add to queue (thread-safe)
        DispatchQueue.main.async {
            self.audioBufferQueue.append(buffer)
            self.accumulatedAudioData.append(contentsOf: buffer.data)
            
            print("📊 Accumulated audio data now contains \(self.accumulatedAudioData.count) samples")
            
            // Maintain buffer size (keep last maxAnalysisTime seconds)
            let maxSamples = Int(self.maxAnalysisTime * buffer.sampleRate)
            if self.accumulatedAudioData.count > maxSamples {
                let excessSamples = self.accumulatedAudioData.count - maxSamples
                self.accumulatedAudioData.removeFirst(excessSamples)
                print("🧹 Trimmed accumulated data to \(self.accumulatedAudioData.count) samples")
            }
            
            // Remove old buffers
            let cutoffTime = Date().addingTimeInterval(-self.maxAnalysisTime)
            let oldCount = self.audioBufferQueue.count
            self.audioBufferQueue.removeAll { $0.timestamp < cutoffTime }
            let removedCount = oldCount - self.audioBufferQueue.count
            if removedCount > 0 {
                print("🗑 Removed \(removedCount) old buffers")
            }
        }
    }
    
    private func setupAnalysisTimer() {
        analysisTimer?.invalidate()
        analysisTimer = Timer.scheduledTimer(withTimeInterval: analysisInterval, repeats: true) { [weak self] _ in
            self?.performAnalysis()
        }
        print("Analysis timer set up with interval: \(self.analysisInterval)s")
    }
    
    private func performAnalysis() {
        guard !accumulatedAudioData.isEmpty else { 
            print("⏭ Skipping analysis - no accumulated audio data")
            return 
        }
        
        print("🔬 Performing analysis with \(accumulatedAudioData.count) samples")
        
        // Create temporary audio file for analysis
        let tempURL = createTemporaryAudioFile(from: accumulatedAudioData)
        
        // Perform analysis
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            print("🚀 Calling audio analyzer with temp file: \(tempURL.path)")
            let result = self.audioAnalyzer.analyzeAudioFile(tempURL.path)
            print("✅ Audio analyzer returned result: \(String(describing: result))")
            
            let chords = self.detectChords(from: self.accumulatedAudioData)
            print("🎼 Detected \(chords.count) chords")
            
            DispatchQueue.main.async {
                if let analysisResult = result {
                    print("📊 Processing analysis result: \(analysisResult.description)")
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
                    print("🎉 Analysis result updated successfully")
                } else {
                    print("❌ Analysis returned nil result")
                }
            }
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
    
    private func smoothAnalysisResult(_ result: AudioAnalysisResult) -> AudioAnalysisResult {
        // All modifications to recentBPMs and recentKeys must happen on the main thread
        DispatchQueue.main.sync {
            // Add to recent results
            self.recentBPMs.append(result.bpm)
            self.recentKeys.append("\(result.key) \(result.scale)")
            
            // Keep only recent results
            if self.recentBPMs.count > self.smoothingWindow {
                self.recentBPMs.removeFirst()
                self.recentKeys.removeFirst()
            }
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
        // More realistic chord detection based on audio characteristics
        // In a real implementation, this would use Essentia's chord detection
        var chords: [ChordDetection] = []
        
        // Calculate audio energy to simulate chord changes
        let segmentSize = max(1, audioData.count / 8) // Divide into 8 segments
        let sampleRate = 44100.0
        
        for i in 0..<8 {
            let startIndex = i * segmentSize
            let endIndex = min(startIndex + segmentSize, audioData.count)
            
            // Skip if we don't have enough data
            guard endIndex > startIndex else { continue }
            
            // Calculate energy for this segment
            let segment = Array(audioData[startIndex..<endIndex])
            let energy = segment.reduce(0.0) { $0 + Double($1 * $1) } / Double(segment.count)
            
            // Determine chord based on energy (simplified simulation)
            let commonChords = ["C", "Dm", "Em", "F", "G", "Am", "Bdim"]
            let chordIndex = Int(energy * Double(commonChords.count)) % commonChords.count
            let chord = commonChords[chordIndex]
            
            // Confidence based on energy stability
            let confidence = min(0.95, 0.3 + Float(energy) * 0.7)
            let startTime = Double(startIndex) / sampleRate
            let duration = Double(endIndex - startIndex) / sampleRate
            
            chords.append(ChordDetection(
                chord: chord,
                confidence: confidence,
                startTime: startTime,
                duration: duration
            ))
        }
        
        return chords
    }
    
    private func createTemporaryAudioFile(from audioData: [Float]) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("tmp_rovodev_analysis_\(UUID().uuidString).wav")
        
        print("Creating temporary audio file at: \(tempURL.path)")
        print("Audio data size: \(audioData.count) samples")
        
        // Create a proper WAV file with header
        let sampleRate: UInt32 = 44100
        let bitDepth: UInt16 = 32
        let channels: UInt16 = 1
        let dataSize = audioData.count * MemoryLayout<Float>.size
        
        var wavData = Data()
        
        // RIFF header
        wavData.append(contentsOf: "RIFF".utf8)
        wavData.append(littleEndian: UInt32(36 + dataSize)) // File size
        wavData.append(contentsOf: "WAVE".utf8)
        
        // Format chunk
        wavData.append(contentsOf: "fmt ".utf8)
        wavData.append(littleEndian: UInt32(16)) // Chunk size
        wavData.append(littleEndian: UInt16(3)) // Format (IEEE Float)
        wavData.append(littleEndian: channels)
        wavData.append(littleEndian: sampleRate)
        wavData.append(littleEndian: UInt32(sampleRate * UInt32(channels) * UInt32(bitDepth) / 8)) // Byte rate
        wavData.append(littleEndian: UInt16(channels * UInt16(bitDepth) / 8)) // Block align
        wavData.append(littleEndian: bitDepth)
        
        // Data chunk
        wavData.append(contentsOf: "data".utf8)
        wavData.append(littleEndian: UInt32(dataSize))
        
        // Audio data
        audioData.withUnsafeBytes { buffer in
            wavData.append(buffer.bindMemory(to: UInt8.self))
        }
        
        do {
            try wavData.write(to: tempURL)
            print("Temporary WAV file created successfully")
        } catch {
            print("Failed to create temporary WAV file: \(error)")
        }
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

// Extension to add little endian data to Data
extension Data {
    mutating func append(littleEndian value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { buffer in
            append(buffer.bindMemory(to: UInt8.self))
        }
    }
    
    mutating func append(littleEndian value: UInt16) {
        Swift.withUnsafeBytes(of: value.littleEndian) { buffer in
            append(buffer.bindMemory(to: UInt8.self))
        }
    }
    
    mutating func append(littleEndian value: Float) {
        let bitPattern = value.bitPattern
        Swift.withUnsafeBytes(of: bitPattern.littleEndian) { buffer in
            append(buffer.bindMemory(to: UInt8.self))
        }
    }
}