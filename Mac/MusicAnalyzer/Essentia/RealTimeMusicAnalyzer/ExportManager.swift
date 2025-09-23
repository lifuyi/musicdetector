//
//  ExportManager.swift
//  Export analysis results to various formats
//

import Foundation
import CoreMIDI
import AVFoundation

class ExportManager: ObservableObject {
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var lastExportURL: URL?
    
    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv = "CSV"
        case midi = "MIDI"
        case xml = "XML"
        case txt = "Text"
        
        var fileExtension: String {
            switch self {
            case .json: return "json"
            case .csv: return "csv"
            case .midi: return "mid"
            case .xml: return "xml"
            case .txt: return "txt"
            }
        }
        
        var description: String {
            switch self {
            case .json: return "Structured data format"
            case .csv: return "Spreadsheet compatible"
            case .midi: return "Musical Instrument Digital Interface"
            case .xml: return "Extensible Markup Language"
            case .txt: return "Plain text format"
            }
        }
    }
    
    // MARK: - Export Methods
    
    func exportAnalysisResults(_ results: [MusicAnalysisResult], format: ExportFormat, to url: URL) {
        isExporting = true
        exportProgress = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                switch format {
                case .json:
                    try self.exportAsJSON(results, to: url)
                case .csv:
                    try self.exportAsCSV(results, to: url)
                case .midi:
                    try self.exportAsMIDI(results, to: url)
                case .xml:
                    try self.exportAsXML(results, to: url)
                case .txt:
                    try self.exportAsText(results, to: url)
                }
                
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.exportProgress = 1.0
                    self.lastExportURL = url
                    print("✅ Export completed: \(url.lastPathComponent)")
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.exportProgress = 0.0
                    print("❌ Export failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - JSON Export
    
    private func exportAsJSON(_ results: [MusicAnalysisResult], to url: URL) throws {
        let exportData = ExportData(
            metadata: ExportMetadata(),
            results: results.map { ExportResult(from: $0) }
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(exportData)
        try jsonData.write(to: url)
        
        updateProgress(0.8)
    }
    
    // MARK: - CSV Export
    
    private func exportAsCSV(_ results: [MusicAnalysisResult], to url: URL) throws {
        var csvContent = "Timestamp,BPM,Key,Scale,Confidence,Chords,Analysis Type\n"
        
        for (index, result) in results.enumerated() {
            let chords = result.chords.map { $0.chord }.joined(separator: ";")
            let line = "\(result.timestamp.ISO8601Format()),\(result.bpm),\(result.key),\(result.scale),\(result.confidence),\"\(chords)\",\(result.analysisType)\n"
            csvContent.append(line)
            
            updateProgress(Double(index) / Double(results.count) * 0.8)
        }
        
        try csvContent.write(to: url, atomically: true, encoding: .utf8)
        updateProgress(1.0)
    }
    
    // MARK: - MIDI Export
    
    private func exportAsMIDI(_ results: [MusicAnalysisResult], to url: URL) throws {
        let midiData = createMIDISequence(from: results)
        try midiData.write(to: url)
        updateProgress(1.0)
    }
    
    private func createMIDISequence(from results: [MusicAnalysisResult]) -> Data {
        var midiData = Data()
        
        // MIDI Header
        midiData.append(contentsOf: [0x4D, 0x54, 0x68, 0x64]) // "MThd"
        midiData.append(contentsOf: [0x00, 0x00, 0x00, 0x06]) // Header length
        midiData.append(contentsOf: [0x00, 0x01]) // Format 1
        midiData.append(contentsOf: [0x00, 0x02]) // 2 tracks
        midiData.append(contentsOf: [0x01, 0xE0]) // 480 ticks per quarter note
        
        // Track 1: Tempo and Key Signature
        var track1Data = Data()
        
        for (index, result) in results.enumerated() {
            let deltaTime = index == 0 ? 0 : 480 // 1 beat apart
            track1Data.append(contentsOf: variableLengthQuantity(deltaTime))
            
            // Tempo change (based on BPM)
            let microsecondsPerQuarter = UInt32(60_000_000 / result.bpm)
            track1Data.append(contentsOf: [0xFF, 0x51, 0x03]) // Set Tempo meta event
            track1Data.append(contentsOf: [
                UInt8((microsecondsPerQuarter >> 16) & 0xFF),
                UInt8((microsecondsPerQuarter >> 8) & 0xFF),
                UInt8(microsecondsPerQuarter & 0xFF)
            ])
            
            updateProgress(Double(index) / Double(results.count) * 0.4)
        }
        
        // End of track
        track1Data.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])
        
        // Track header
        midiData.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B]) // "MTrk"
        let track1Length = UInt32(track1Data.count)
        midiData.append(contentsOf: [
            UInt8((track1Length >> 24) & 0xFF),
            UInt8((track1Length >> 16) & 0xFF),
            UInt8((track1Length >> 8) & 0xFF),
            UInt8(track1Length & 0xFF)
        ])
        midiData.append(track1Data)
        
        // Track 2: Chord Progression
        var track2Data = Data()
        
        for (index, result) in results.enumerated() {
            let deltaTime = index == 0 ? 0 : 480
            track2Data.append(contentsOf: variableLengthQuantity(deltaTime))
            
            // Play chord notes
            for chord in result.chords.prefix(1) { // First chord only
                let midiNotes = chordToMIDINotes(chord.chord, key: result.key)
                
                // Note On events
                for note in midiNotes {
                    track2Data.append(contentsOf: [0x90, note, 0x60]) // Channel 0, velocity 96
                }
                
                // Note Off events (after some duration)
                track2Data.append(contentsOf: variableLengthQuantity(240)) // Half beat
                for note in midiNotes {
                    track2Data.append(contentsOf: [0x80, note, 0x40]) // Note off
                }
            }
            
            updateProgress(0.4 + Double(index) / Double(results.count) * 0.4)
        }
        
        // End of track
        track2Data.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])
        
        // Track 2 header
        midiData.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B]) // "MTrk"
        let track2Length = UInt32(track2Data.count)
        midiData.append(contentsOf: [
            UInt8((track2Length >> 24) & 0xFF),
            UInt8((track2Length >> 16) & 0xFF),
            UInt8((track2Length >> 8) & 0xFF),
            UInt8(track2Length & 0xFF)
        ])
        midiData.append(track2Data)
        
        return midiData
    }
    
    private func variableLengthQuantity(_ value: Int) -> [UInt8] {
        if value < 128 {
            return [UInt8(value)]
        } else if value < 16384 {
            return [UInt8((value >> 7) | 0x80), UInt8(value & 0x7F)]
        } else {
            return [UInt8((value >> 14) | 0x80), UInt8(((value >> 7) & 0x7F) | 0x80), UInt8(value & 0x7F)]
        }
    }
    
    private func chordToMIDINotes(_ chord: String, key: String) -> [UInt8] {
        let keyOffset = keyToMIDIOffset(key)
        let baseNote = 60 + keyOffset // C4 + key offset
        
        // Simple chord mapping (add more sophisticated parsing later)
        switch chord.uppercased() {
        case "C", "I":
            return [UInt8(baseNote), UInt8(baseNote + 4), UInt8(baseNote + 7)] // Major triad
        case "DM", "II":
            return [UInt8(baseNote + 2), UInt8(baseNote + 6), UInt8(baseNote + 9)]
        case "EM", "III":
            return [UInt8(baseNote + 4), UInt8(baseNote + 8), UInt8(baseNote + 11)]
        case "F", "IV":
            return [UInt8(baseNote + 5), UInt8(baseNote + 9), UInt8(baseNote + 12)]
        case "G", "V":
            return [UInt8(baseNote + 7), UInt8(baseNote + 11), UInt8(baseNote + 14)]
        case "AM", "VI":
            return [UInt8(baseNote + 9), UInt8(baseNote + 12), UInt8(baseNote + 16)]
        case "BDIM", "VII":
            return [UInt8(baseNote + 11), UInt8(baseNote + 14), UInt8(baseNote + 17)]
        default:
            return [UInt8(baseNote), UInt8(baseNote + 4), UInt8(baseNote + 7)] // Default to major
        }
    }
    
    private func keyToMIDIOffset(_ key: String) -> Int {
        switch key.uppercased() {
        case "C": return 0
        case "C#", "DB": return 1
        case "D": return 2
        case "D#", "EB": return 3
        case "E": return 4
        case "F": return 5
        case "F#", "GB": return 6
        case "G": return 7
        case "G#", "AB": return 8
        case "A": return 9
        case "A#", "BB": return 10
        case "B": return 11
        default: return 0
        }
    }
    
    // MARK: - XML Export
    
    private func exportAsXML(_ results: [MusicAnalysisResult], to url: URL) throws {
        var xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <music_analysis>
            <metadata>
                <exported_at>\(Date().ISO8601Format())</exported_at>
                <app_version>1.0.0</app_version>
                <result_count>\(results.count)</result_count>
            </metadata>
            <results>
        """
        
        for (index, result) in results.enumerated() {
            xmlContent += """
            
                <result id="\(result.id)">
                    <timestamp>\(result.timestamp.ISO8601Format())</timestamp>
                    <bpm>\(result.bpm)</bpm>
                    <key>\(result.key)</key>
                    <scale>\(result.scale)</scale>
                    <confidence>\(result.confidence)</confidence>
                    <analysis_type>\(result.analysisType)</analysis_type>
                    <chords>
            """
            
            for chord in result.chords {
                xmlContent += """
                
                        <chord>
                            <name>\(chord.chord)</name>
                            <confidence>\(chord.confidence)</confidence>
                            <start_time>\(chord.startTime)</start_time>
                            <duration>\(chord.duration)</duration>
                        </chord>
                """
            }
            
            xmlContent += """
            
                    </chords>
                </result>
            """
            
            updateProgress(Double(index) / Double(results.count) * 0.8)
        }
        
        xmlContent += """
        
            </results>
        </music_analysis>
        """
        
        try xmlContent.write(to: url, atomically: true, encoding: .utf8)
        updateProgress(1.0)
    }
    
    // MARK: - Text Export
    
    private func exportAsText(_ results: [MusicAnalysisResult], to url: URL) throws {
        var textContent = """
        MUSIC ANALYSIS RESULTS
        ======================
        
        Exported: \(Date().formatted())
        Total Results: \(results.count)
        
        """
        
        for (index, result) in results.enumerated() {
            textContent += """
            
            Result #\(index + 1) [\(result.id.uuidString.prefix(8))]
            ----------------------------------------
            Time: \(result.timestamp.formatted())
            BPM: \(String(format: "%.1f", result.bpm))
            Key: \(result.key) \(result.scale)
            Confidence: \(String(format: "%.1f%%", result.confidence * 100))
            Analysis Type: \(result.analysisType)
            
            """
            
            if !result.chords.isEmpty {
                textContent += "Chords: "
                let chordStrings = result.chords.map { "\($0.chord) (\(String(format: "%.1f%%", $0.confidence * 100)))" }
                textContent += chordStrings.joined(separator: ", ")
                textContent += "\n"
            }
            
            updateProgress(Double(index) / Double(results.count) * 0.8)
        }
        
        try textContent.write(to: url, atomically: true, encoding: .utf8)
        updateProgress(1.0)
    }
    
    private func updateProgress(_ progress: Double) {
        DispatchQueue.main.async {
            self.exportProgress = progress
        }
    }
}

// MARK: - Export Data Structures

struct ExportData: Codable {
    let metadata: ExportMetadata
    let results: [ExportResult]
}

struct ExportMetadata: Codable {
    let exportedAt: Date
    let appVersion: String
    let resultCount: Int
    
    init() {
        self.exportedAt = Date()
        self.appVersion = "1.0.0"
        self.resultCount = 0
    }
}

struct ExportResult: Codable {
    let id: String
    let timestamp: Date
    let bpm: Float
    let key: String
    let scale: String
    let confidence: Float
    let analysisType: String
    let chords: [ExportChord]
    
    init(from result: MusicAnalysisResult) {
        self.id = result.id.uuidString
        self.timestamp = result.timestamp
        self.bpm = result.bpm
        self.key = result.key
        self.scale = result.scale
        self.confidence = result.confidence
        self.analysisType = "\(result.analysisType)"
        self.chords = result.chords.map { ExportChord(from: $0) }
    }
}

struct ExportChord: Codable {
    let chord: String
    let confidence: Float
    let startTime: TimeInterval
    let duration: TimeInterval
    
    init(from chord: ChordDetection) {
        self.chord = chord.chord
        self.confidence = chord.confidence
        self.startTime = chord.startTime
        self.duration = chord.duration
    }
}