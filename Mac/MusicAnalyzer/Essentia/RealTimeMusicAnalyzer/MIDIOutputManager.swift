//
//  MIDIOutputManager.swift
//  Real-time MIDI output for DAW integration
//

import Foundation
import CoreMIDI
import Combine

class MIDIOutputManager: NSObject, ObservableObject {
    @Published var isEnabled = false
    @Published var availablePorts: [MIDIPortInfo] = []
    @Published var selectedPort: MIDIPortInfo?
    @Published var lastSentMessage: String = ""
    
    private var midiClient: MIDIClientRef = 0
    private var outputPort: MIDIPortRef = 0
    private var virtualSource: MIDIEndpointRef = 0
    
    override init() {
        super.init()
        setupMIDI()
        scanForPorts()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - MIDI Setup
    
    private func setupMIDI() {
        var status = MIDIClientCreate("RealTimeMusicAnalyzer" as CFString, nil, nil, &midiClient)
        guard status == noErr else {
            print("Failed to create MIDI client: \(status)")
            return
        }
        
        status = MIDIOutputPortCreate(midiClient, "AnalysisOutput" as CFString, &outputPort)
        guard status == noErr else {
            print("Failed to create MIDI output port: \(status)")
            return
        }
        
        // Create virtual MIDI source
        status = MIDISourceCreate(midiClient, "Music Analyzer" as CFString, &virtualSource)
        guard status == noErr else {
            print("Failed to create virtual MIDI source: \(status)")
            return
        }
        
        isEnabled = true
        print("✅ MIDI system initialized successfully")
    }
    
    private func cleanup() {
        if virtualSource != 0 {
            MIDIEndpointDispose(virtualSource)
        }
        if outputPort != 0 {
            MIDIPortDispose(outputPort)
        }
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
        }
    }
    
    // MARK: - Port Management
    
    func scanForPorts() {
        availablePorts.removeAll()
        
        let destCount = MIDIGetNumberOfDestinations()
        for i in 0..<destCount {
            let dest = MIDIGetDestination(i)
            if let portInfo = getPortInfo(for: dest) {
                availablePorts.append(portInfo)
            }
        }
        
        // Add virtual source as option
        availablePorts.insert(MIDIPortInfo(
            endpoint: virtualSource,
            name: "Music Analyzer (Virtual)",
            isVirtual: true
        ), at: 0)
        
        if selectedPort == nil && !availablePorts.isEmpty {
            selectedPort = availablePorts.first
        }
        
        print("📱 Found \(availablePorts.count) MIDI destinations")
    }
    
    private func getPortInfo(for endpoint: MIDIEndpointRef) -> MIDIPortInfo? {
        var name: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)
        
        guard status == noErr, let cfName = name?.takeRetainedValue() else {
            return nil
        }
        
        return MIDIPortInfo(
            endpoint: endpoint,
            name: String(cfName),
            isVirtual: false
        )
    }
    
    // MARK: - Real-time Analysis Output
    
    func sendAnalysisUpdate(_ result: MusicAnalysisResult) {
        guard isEnabled, let port = selectedPort else { return }
        
        // Send BPM as MIDI Clock
        sendMIDIClock(bpm: result.bpm)
        
        // Send Key as Program Change
        sendKeyChange(key: result.key, scale: result.scale)
        
        // Send Chords as Note Events
        for chord in result.chords {
            sendChord(chord, in: result.key)
        }
        
        // Send Confidence as CC
        sendConfidence(result.confidence)
        
        DispatchQueue.main.async {
            self.lastSentMessage = "BPM: \(String(format: "%.1f", result.bpm)), Key: \(result.key) \(result.scale)"
        }
    }
    
    // MARK: - MIDI Message Sending
    
    private func sendMIDIClock(bpm: Float) {
        // Calculate MIDI clock timing (24 clocks per quarter note)
        let clockInterval = 60.0 / (Double(bpm) * 24.0)
        
        // Send timing clock messages
        let clockMessage = MIDIPacket(timeStamp: 0, data: [0xF8])
        sendMIDIPacket(clockMessage)
    }
    
    private func sendKeyChange(key: String, scale: String) {
        // Map musical keys to MIDI program numbers
        let keyNumber = musicalKeyToMIDI(key: key, scale: scale)
        
        // Send Program Change (Channel 1)
        let programChange = MIDIPacket(timeStamp: 0, data: [0xC0, UInt8(keyNumber)])
        sendMIDIPacket(programChange)
    }
    
    private func sendChord(_ chord: ChordDetection, in key: String) {
        let midiNotes = chordToMIDINotes(chord.chord, key: key)
        let velocity = UInt8(min(127, max(1, chord.confidence * 127)))
        
        // Send Note On for all chord notes
        for note in midiNotes {
            let noteOn = MIDIPacket(timeStamp: 0, data: [0x91, note, velocity]) // Channel 2
            sendMIDIPacket(noteOn)
        }
        
        // Schedule Note Off after chord duration
        DispatchQueue.main.asyncAfter(deadline: .now() + chord.duration) {
            for note in midiNotes {
                let noteOff = MIDIPacket(timeStamp: 0, data: [0x81, note, 0])
                self.sendMIDIPacket(noteOff)
            }
        }
    }
    
    private func sendConfidence(_ confidence: Float) {
        // Send confidence as MIDI CC #1 (Modulation)
        let ccValue = UInt8(confidence * 127)
        let controlChange = MIDIPacket(timeStamp: 0, data: [0xB2, 0x01, ccValue]) // Channel 3
        sendMIDIPacket(controlChange)
    }
    
    private func sendMIDIPacket(_ packet: MIDIPacket) {
        guard let port = selectedPort else { return }
        
        var midiPacket = packet
        let packetList = UnsafeMutablePointer<MIDIPacketList>.allocate(capacity: 1)
        defer { packetList.deallocate() }
        
        packetList.pointee.numPackets = 1
        packetList.pointee.packet = midiPacket
        
        let status: OSStatus
        if port.isVirtual {
            status = MIDIReceived(virtualSource, packetList)
        } else {
            status = MIDISend(outputPort, port.endpoint, packetList)
        }
        
        if status != noErr {
            print("MIDI send error: \(status)")
        }
    }
    
    // MARK: - MIDI Mapping Utilities
    
    private func musicalKeyToMIDI(key: String, scale: String) -> Int {
        let keyOffset = keyToOffset(key)
        let scaleOffset = scale.lowercased() == "minor" ? 12 : 0
        return keyOffset + scaleOffset
    }
    
    private func keyToOffset(_ key: String) -> Int {
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
    
    private func chordToMIDINotes(_ chord: String, key: String) -> [UInt8] {
        let keyOffset = keyToOffset(key)
        let baseNote = 60 + keyOffset // C4 + key offset
        
        // Enhanced chord mapping
        switch chord.uppercased() {
        case "C", "I":
            return [UInt8(baseNote), UInt8(baseNote + 4), UInt8(baseNote + 7)]
        case "CM7":
            return [UInt8(baseNote), UInt8(baseNote + 4), UInt8(baseNote + 7), UInt8(baseNote + 11)]
        case "DM", "II":
            return [UInt8(baseNote + 2), UInt8(baseNote + 6), UInt8(baseNote + 9)]
        case "EM", "III":
            return [UInt8(baseNote + 4), UInt8(baseNote + 8), UInt8(baseNote + 11)]
        case "F", "IV":
            return [UInt8(baseNote + 5), UInt8(baseNote + 9), UInt8(baseNote + 12)]
        case "G", "V":
            return [UInt8(baseNote + 7), UInt8(baseNote + 11), UInt8(baseNote + 14)]
        case "G7":
            return [UInt8(baseNote + 7), UInt8(baseNote + 11), UInt8(baseNote + 14), UInt8(baseNote + 17)]
        case "AM", "VI":
            return [UInt8(baseNote + 9), UInt8(baseNote + 12), UInt8(baseNote + 16)]
        case "BDIM", "VII":
            return [UInt8(baseNote + 11), UInt8(baseNote + 14), UInt8(baseNote + 17)]
        default:
            return [UInt8(baseNote), UInt8(baseNote + 4), UInt8(baseNote + 7)]
        }
    }
    
    // MARK: - Real-time Features
    
    func sendTapTempo(_ bpm: Float) {
        // Send tap tempo as MIDI Start/Continue
        let startMessage = MIDIPacket(timeStamp: 0, data: [0xFA]) // MIDI Start
        sendMIDIPacket(startMessage)
        
        // Follow with clock at specified BPM
        sendMIDIClock(bpm: bpm)
    }
    
    func sendTransportControl(_ command: TransportCommand) {
        let midiCommand: UInt8
        switch command {
        case .start: midiCommand = 0xFA
        case .stop: midiCommand = 0xFC
        case .`continue`: midiCommand = 0xFB
        }
        
        let transportMessage = MIDIPacket(timeStamp: 0, data: [midiCommand])
        sendMIDIPacket(transportMessage)
    }
    
    // MARK: - DAW Integration Presets
    
    func setupForDAW(_ daw: DAWType) {
        switch daw {
        case .logicPro:
            // Logic Pro specific MIDI mapping
            break
        case .ableton:
            // Ableton Live specific mapping
            break
        case .proTools:
            // Pro Tools specific mapping
            break
        case .cubase:
            // Cubase specific mapping
            break
        }
    }
}

// MARK: - Supporting Types

struct MIDIPortInfo: Identifiable, Equatable, Hashable {
    let id = UUID()
    let endpoint: MIDIEndpointRef
    let name: String
    let isVirtual: Bool
    
    static func == (lhs: MIDIPortInfo, rhs: MIDIPortInfo) -> Bool {
        return lhs.endpoint == rhs.endpoint && lhs.name == rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(endpoint)
        hasher.combine(name)
        hasher.combine(isVirtual)
    }
}

extension MIDIPacket {
    init(timeStamp: MIDITimeStamp, data: [UInt8]) {
        self.init()
        self.timeStamp = timeStamp
        self.length = UInt16(data.count)
        
        // Copy data into the packet
        withUnsafeMutableBytes(of: &self.data) { buffer in
            for (index, byte) in data.enumerated() {
                if index < 256 { // Maximum MIDI packet size
                    buffer[index] = byte
                }
            }
        }
    }
}

enum TransportCommand {
    case start
    case stop
    case `continue`
}

enum DAWType {
    case logicPro
    case ableton
    case proTools
    case cubase
}