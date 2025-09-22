import Foundation

// MARK: - 音乐理论数据结构
struct MusicKey {
    let root: Int // 0-11 (C=0, C#=1, ...)
    let mode: KeyMode
    let confidence: Float
}

enum KeyMode: String, CaseIterable {
    case major = "大调"
    case minor = "小调"
    
    var profile: [Float] {
        switch self {
        case .major:
            return [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
        case .minor:
            return [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
        }
    }
}

struct ChordDetection {
    let root: Int
    let quality: ChordQuality
    let confidence: Float
    let romanNumeral: String
    let timestamp: Date
}

enum ChordQuality: String, CaseIterable {
    case major = "大三和弦"
    case minor = "小三和弦"
    case diminished = "减三和弦"
    case augmented = "增三和弦"
    case major7 = "大七和弦"
    case minor7 = "小七和弦"
    case dominant7 = "属七和弦"
    
    var intervals: [Int] {
        switch self {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .diminished: return [0, 3, 6]
        case .augmented: return [0, 4, 8]
        case .major7: return [0, 4, 7, 11]
        case .minor7: return [0, 3, 7, 10]
        case .dominant7: return [0, 4, 7, 10]
        }
    }
}

struct BeatInfo {
    let bpm: Float
    let timeSignature: TimeSignature
    let confidence: Float
    let beatPosition: Float // 0.0-1.0 在当前拍子中的位置
    let measurePosition: Int // 当前小节中的拍子位置
}

struct TimeSignature {
    let numerator: Int
    let denominator: Int
    
    var description: String {
        return "\(numerator)/\(denominator)"
    }
}

// MARK: - 主分析引擎
class MusicAnalysisEngine {
    
    // 分析参数
    private let keyConfidenceThreshold: Float = 0.7
    private let chordConfidenceThreshold: Float = 0.6
    private let beatHistorySize = 50
    
    // 历史数据
    private var featureHistory: [AudioFeatures] = []
    private var beatHistory: [Double] = []
    private var currentKey: MusicKey?
    private var chordHistory: [ChordDetection] = []
    
    // 节拍检测
    private var lastBeatTime: Double = 0
    private var bpmEstimate: Float = 120
    private var beatPhase: Float = 0
    
    func analyze(_ features: AudioFeatures) -> MusicAnalysisResult {
        featureHistory.append(features)
        
        // 保持历史数据在合理范围内
        if featureHistory.count > 100 {
            featureHistory.removeFirst()
        }
        
        // 分析各个组件
        let beatInfo = analyzeBeat(features)
        let keyDetection = analyzeKey()
        let chordDetection = analyzeChord(features, currentKey: keyDetection)
        
        // 更新状态
        if let key = keyDetection {
            currentKey = key
        }
        
        if let chord = chordDetection {
            chordHistory.append(chord)
            if chordHistory.count > 20 {
                chordHistory.removeFirst()
            }
        }
        
        return MusicAnalysisResult(
            key: keyDetection,
            chord: chordDetection,
            beat: beatInfo,
            chordProgression: getRecentChordProgression()
        )
    }
    
    // MARK: - 节拍分析
    private func analyzeBeat(_ features: AudioFeatures) -> BeatInfo {
        let currentTime = features.timestamp.timeIntervalSince1970
        
        // 简化的节拍检测：基于谱质心和能量变化
        let energy = features.magnitude.reduce(0, +)
        let energyChange = featureHistory.count > 1 ? 
            energy - featureHistory[featureHistory.count - 2].magnitude.reduce(0, +) : 0
        
        // 检测可能的拍点
        if energyChange > 0.1 && currentTime - lastBeatTime > 0.3 {
            let interval = currentTime - lastBeatTime
            if interval > 0.4 && interval < 1.2 { // 50-150 BPM范围
                beatHistory.append(interval)
                if beatHistory.count > beatHistorySize {
                    beatHistory.removeFirst()
                }
                
                // 更新BPM估计
                if beatHistory.count > 5 {
                    let averageInterval = beatHistory.suffix(10).reduce(0, +) / Double(min(10, beatHistory.count))
                    bpmEstimate = Float(60.0 / averageInterval)
                }
                
                lastBeatTime = currentTime
            }
        }
        
        // 计算拍子位置
        let timeSinceLastBeat = Float(currentTime - lastBeatTime)
        let beatLength = 60.0 / bpmEstimate
        beatPhase = (timeSinceLastBeat / beatLength).truncatingRemainder(dividingBy: 1.0)
        
        // 简单的4/4拍假设
        let measurePosition = Int(timeSinceLastBeat / beatLength) % 4 + 1
        
        return BeatInfo(
            bpm: bpmEstimate,
            timeSignature: TimeSignature(numerator: 4, denominator: 4),
            confidence: min(Float(beatHistory.count) / Float(beatHistorySize), 1.0),
            beatPosition: beatPhase,
            measurePosition: measurePosition
        )
    }
    
    // MARK: - 调式分析
    private func analyzeKey() -> MusicKey? {
        guard featureHistory.count >= 10 else { return nil }
        
        // 累积最近的色彩特征
        let recentFeatures = featureHistory.suffix(20)
        var accumulatedChroma = Array(repeating: Float(0.0), count: 12)
        
        for features in recentFeatures {
            for i in 0..<12 {
                accumulatedChroma[i] += features.chroma[i]
            }
        }
        
        // 归一化
        let sum = accumulatedChroma.reduce(0, +)
        if sum > 0 {
            for i in 0..<12 {
                accumulatedChroma[i] /= sum
            }
        }
        
        // 使用Krumhansl-Schmuckler算法
        var bestKey: MusicKey?
        var bestCorrelation: Float = 0
        
        for root in 0..<12 {
            for mode in KeyMode.allCases {
                let correlation = calculateKeyCorrelation(chroma: accumulatedChroma, 
                                                        root: root, 
                                                        mode: mode)
                if correlation > bestCorrelation {
                    bestCorrelation = correlation
                    bestKey = MusicKey(root: root, mode: mode, confidence: correlation)
                }
            }
        }
        
        // 只有当置信度足够高时才返回结果
        if let key = bestKey, key.confidence >= keyConfidenceThreshold {
            return key
        }
        
        return nil
    }
    
    private func calculateKeyCorrelation(chroma: [Float], root: Int, mode: KeyMode) -> Float {
        let profile = mode.profile
        var correlation: Float = 0
        
        for i in 0..<12 {
            let rotatedIndex = (i + root) % 12
            correlation += chroma[i] * profile[rotatedIndex]
        }
        
        return correlation
    }
    
    // MARK: - 和弦分析
    private func analyzeChord(_ features: AudioFeatures, currentKey: MusicKey?) -> ChordDetection? {
        let chroma = features.chroma
        
        var bestChord: ChordDetection?
        var bestScore: Float = 0
        
        // 测试所有可能的和弦
        for root in 0..<12 {
            for quality in ChordQuality.allCases {
                let score = calculateChordScore(chroma: chroma, root: root, quality: quality)
                if score > bestScore {
                    bestScore = score
                    
                    let romanNumeral = getRomanNumeral(root: root, quality: quality, key: currentKey)
                    bestChord = ChordDetection(
                        root: root,
                        quality: quality,
                        confidence: score,
                        romanNumeral: romanNumeral,
                        timestamp: features.timestamp
                    )
                }
            }
        }
        
        if let chord = bestChord, chord.confidence >= chordConfidenceThreshold {
            return chord
        }
        
        return nil
    }
    
    private func calculateChordScore(chroma: [Float], root: Int, quality: ChordQuality) -> Float {
        let intervals = quality.intervals
        var score: Float = 0
        var totalWeight: Float = 0
        
        for (index, interval) in intervals.enumerated() {
            let chromaIndex = (root + interval) % 12
            let weight: Float = index == 0 ? 3.0 : (index == 1 ? 2.0 : 1.5) // 根音权重最高
            score += chroma[chromaIndex] * weight
            totalWeight += weight
        }
        
        // 减去不在和弦中的音符的贡献
        for i in 0..<12 {
            if !intervals.contains((i - root + 12) % 12) {
                score -= chroma[i] * 0.5
            }
        }
        
        return max(0, score / totalWeight)
    }
    
    private func getRomanNumeral(root: Int, quality: ChordQuality, key: MusicKey?) -> String {
        guard let key = key else {
            return noteNames[root] + quality.rawValue
        }
        
        let degree = (root - key.root + 12) % 12
        let romanNumerals = ["I", "II", "III", "IV", "V", "VI", "VII"]
        let scaleSteps = [0, 2, 4, 5, 7, 9, 11] // 大调音阶
        
        // 找到最接近的音阶级数
        var closestStep = 0
        var minDistance = 12
        for (index, step) in scaleSteps.enumerated() {
            let distance = min(abs(degree - step), abs(degree - step + 12), abs(degree - step - 12))
            if distance < minDistance {
                minDistance = distance
                closestStep = index
            }
        }
        
        var numeral = romanNumerals[closestStep]
        
        // 根据和弦质量调整大小写
        switch quality {
        case .minor, .diminished, .minor7:
            numeral = numeral.lowercased()
        case .diminished:
            numeral += "°"
        case .dominant7:
            numeral += "7"
        case .major7:
            numeral += "maj7"
        case .minor7:
            numeral += "7"
        default:
            break
        }
        
        return numeral
    }
    
    private func getRecentChordProgression() -> [ChordDetection] {
        return Array(chordHistory.suffix(8))
    }
}

// MARK: - 辅助常量
private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

// MARK: - 分析结果
struct MusicAnalysisResult {
    let key: MusicKey?
    let chord: ChordDetection?
    let beat: BeatInfo
    let chordProgression: [ChordDetection]
}