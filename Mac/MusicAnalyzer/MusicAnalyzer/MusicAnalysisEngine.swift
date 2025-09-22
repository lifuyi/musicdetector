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
    
    // 改进的profile，强调调式特征音
    var enhancedProfile: [Float] {
        switch self {
        case .major:
            // 强化主音(1)、三音(3)、五音(5)
            return [8.0, 2.0, 4.5, 2.0, 5.5, 4.5, 2.0, 6.5, 2.0, 3.5, 2.0, 3.0]
        case .minor:
            // 强化主音(1)、小三音(♭3)、五音(5)、小七音(♭7)
            return [8.0, 2.5, 3.0, 6.0, 2.5, 4.5, 2.5, 6.0, 3.5, 2.5, 4.0, 3.5]
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
    
    // MARK: - Essentia 集成
    private let essentiaClient = EssentiaAPIClient.shared
    private var lastEssentiaResult: EssentiaAnalysisResult?
    private var essentiaAvailable = false
    
    // 混合分析状态
    private var useHybridAnalysis = true
    private var essentiaResultCache: [String: EssentiaAnalysisResult] = [:]
    
    // 分析参数 - 极低的阈值确保能检测到结果
    private let keyConfidenceThreshold: Float = 0.001  // 从0.01降到0.001，几乎无门槛
    private let chordConfidenceThreshold: Float = 0.1  // 从0.2降到0.1
    private let beatHistorySize = 50
    
    // 历史数据
    private var featureHistory: [AudioFeatures] = []
    private var beatHistory: [Double] = []
    private var currentKey: MusicKey?
    private var chordHistory: [ChordDetection] = []
    
    // 节拍检测 - 改进版本
    private var lastBeatTime: Double = 0
    private var bpmEstimate: Float = 0  // 初始为0，表示未检测到
    private var beatPhase: Float = 0
    private var onsetStrengths: [Float] = []
    private var tempoBins: [Float] = Array(repeating: 0, count: 200) // 60-260 BPM
    private var beatTracker: BeatTracker = BeatTracker()
    private var hasValidBPM: Bool = false
    private let minOnsetCount = 10  // 从20降到10，更快检测
    
    func analyze(_ features: AudioFeatures) -> MusicAnalysisResult {
        return analyzeHybrid(features, audioFileURL: nil)
    }
    
    /// 混合分析：结合本地实时分析和 Essentia 精确分析
    func analyzeHybrid(_ features: AudioFeatures, audioFileURL: URL?) -> MusicAnalysisResult {
        featureHistory.append(features)
        
        // 保持历史数据在合理范围内
        if featureHistory.count > 100 {
            featureHistory.removeFirst()
        }
        
        print("🎵 Feature history: \(featureHistory.count) samples")
        
        // 分析各个组件
        let beatInfo = analyzeBeat(features)
        let keyDetection = analyzeKey()
        let chordDetection = analyzeChord(features, currentKey: keyDetection)
        
        // 调试输出
        if let key = keyDetection {
            print("🎵 Key detected: \(noteNames[key.root])\(key.mode.rawValue) (confidence: \(key.confidence))")
        } else {
            print("🎵 Key detection: below threshold (history: \(featureHistory.count))")
        }
        
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
        
        // 本地分析结果
        let localResult = MusicAnalysisResult(
            key: keyDetection,
            chord: chordDetection,
            beat: beatInfo,
            chordProgression: getRecentChordProgression()
        )
        
        // 如果有音频文件且启用混合分析，尝试使用 Essentia 结果增强
        if let fileURL = audioFileURL, useHybridAnalysis {
            Task {
                await enhanceWithEssentia(fileURL: fileURL)
            }
        }
        
        // 如果有缓存的 Essentia 结果，使用它来增强本地结果
        if let essentiaResult = lastEssentiaResult {
            return mergeResults(local: localResult, essentia: essentiaResult)
        }
        
        return localResult
    }
    
    // MARK: - 节拍分析 - 改进版本
    private func analyzeBeat(_ features: AudioFeatures) -> BeatInfo {
        let currentTime = features.timestamp.timeIntervalSince1970
        
        // 计算onset strength（起始强度）
        let onsetStrength = calculateOnsetStrength(features)
        onsetStrengths.append(onsetStrength)
        
        // 保持合理的历史长度
        if onsetStrengths.count > 100 {  // 从200降低到100
            onsetStrengths.removeFirst()
        }
        
        print("📊 Onset detection: \(onsetStrengths.count)/3 samples, current strength: \(String(format: "%.3f", onsetStrength))")
        
        // 需要足够的数据进行分析 - 大幅降低要求
        guard onsetStrengths.count >= 3 else {  // 从10降到3，更快检测
            print("⏳ Waiting for more onset data (current: \(onsetStrengths.count)/3)...")
            return BeatInfo(
                bpm: hasValidBPM ? bpmEstimate : 0,  // 如果没有有效BPM，返回0而不是默认值
                timeSignature: TimeSignature(numerator: 4, denominator: 4),
                confidence: 0.0,
                beatPosition: 0.0,
                measurePosition: 1
            )
        }
        
        // 动态规划beat tracking
        let beatInfo = beatTracker.track(onsetStrengths: onsetStrengths, currentTime: currentTime)
        
        print("🎯 Beat tracking result: BPM=\(beatInfo.bpm), Confidence=\(String(format: "%.2f", beatInfo.confidence))")
        
        // 更新内部状态 - 只在检测到有效BPM时更新 - 大幅降低置信度要求
        if beatInfo.bpm > 0 && beatInfo.confidence > 0.005 {  // 从0.02降到0.005
            bpmEstimate = beatInfo.bpm
            hasValidBPM = true
            print("✅ BPM updated: \(bpmEstimate)")
        } else {
            print("❌ BPM detection failed - confidence: \(beatInfo.confidence), threshold: 0.005")
            // 即使置信度低也暂时接受，避免一直显示检测中
            if beatInfo.bpm > 0 {
                bpmEstimate = beatInfo.bpm
                hasValidBPM = true
                print("⚠️ BPM accepted with low confidence: \(bpmEstimate)")
            }
        }
        beatPhase = beatInfo.beatPosition
        
        return beatInfo
    }
    
    private func calculateOnsetStrength(_ features: AudioFeatures) -> Float {
        guard featureHistory.count > 0 else { return 0 }
        
        let current = features.magnitude
        let previous = featureHistory.last!.magnitude
        
        // 计算谱通量（spectral flux）
        var spectralFlux: Float = 0
        for i in 0..<min(current.count, previous.count) {
            let diff = current[i] - previous[i]
            if diff > 0 {
                spectralFlux += diff
            }
        }
        
        // 高频增强（检测瞬态更敏感）
        var highFreqFlux: Float = 0
        let highFreqStart = current.count / 4
        for i in highFreqStart..<min(current.count, previous.count) {
            let diff = current[i] - previous[i]
            if diff > 0 {
                highFreqFlux += diff * 2.0 // 高频权重加倍
            }
        }
        
        // 综合onset强度
        let totalOnset = spectralFlux + highFreqFlux
        
        // 自适应阈值 - 添加边界检查
        let recentCount = min(10, onsetStrengths.count)
        guard recentCount > 0 else {
            return max(0, totalOnset)  // 没有历史数据时返回原始值
        }
        let recentMean = onsetStrengths.suffix(recentCount).reduce(0, +) / Float(recentCount)
        let adaptiveThreshold = recentMean * 1.2  // 从1.5降低到1.2，更敏感
        
        return max(0, totalOnset - adaptiveThreshold)
    }
    
    // MARK: - 调式分析 - 改进版本
    private func analyzeKey() -> MusicKey? {
        guard featureHistory.count >= 1 else {  // 从3降到1，只要有1个样本就开始检测
            print("🎵 Key detection: waiting for feature data (current: \(featureHistory.count))")
            return nil
        }
        
        print("🎵 Starting key detection with \(featureHistory.count) feature samples")
        
        // 使用更长的历史和加权平均 - 添加边界检查
        let recentFeatureCount = min(40, featureHistory.count)
        let recentFeatures = featureHistory.suffix(recentFeatureCount)
        var weightedChroma = Array(repeating: Float(0.0), count: 12)
        var totalWeight: Float = 0
        
        // 使用时间衰减权重
        for (index, features) in recentFeatures.enumerated() {
            let weight = Float(index + 1) / Float(recentFeatures.count) // 越新的权重越大
            for i in 0..<12 {
                weightedChroma[i] += features.chroma[i] * weight
            }
            totalWeight += weight
        }
        
        // 归一化
        if totalWeight > 0 {
            for i in 0..<12 {
                weightedChroma[i] /= totalWeight
            }
        }
        
        // 改进的Krumhansl-Schmuckler算法
        var keyScores: [(root: Int, mode: KeyMode, score: Float)] = []
        
        for root in 0..<12 {
            for mode in KeyMode.allCases {
                let score = calculateImprovedKeyScore(chroma: weightedChroma, root: root, mode: mode)
                keyScores.append((root: root, mode: mode, score: score))
            }
        }
        
        // 排序获得最佳匹配
        keyScores.sort { $0.score > $1.score }
        
        print("🎵 Key detection: found \(keyScores.count) candidates, best score: \(String(format: "%.4f", keyScores.first?.score ?? 0))")
        
        guard let best = keyScores.first, best.score >= keyConfidenceThreshold else {
            let failedScore = keyScores.first?.score ?? 0
            print("🎵 Key detection failed: score \(String(format: "%.4f", failedScore)) < threshold \(keyConfidenceThreshold)")
            return nil
        }
        
        // 检查稳定性：最佳结果应该明显优于第二好的 - 移除稳定性要求
        if keyScores.count > 1 {
            let stabilityRatio = best.score / keyScores[1].score
            print("🎵 Key stability ratio: \(String(format: "%.2f", stabilityRatio))")
        }
        
        // 移除稳定性检查，让任何通过阈值的结果都能显示
        // if stabilityRatio < 1.02 { return nil }
        
        print("🎵 Key detection successful: \(noteNames[best.root])\(best.mode.rawValue) (confidence: \(best.score))")
        
        // 与历史调式比较，避免频繁变化（放宽条件）
        if let currentKey = currentKey {
            let stability = calculateKeyStability(newKey: (best.root, best.mode), 
                                                oldKey: (currentKey.root, currentKey.mode))
            if stability < 0.5 && best.score < keyConfidenceThreshold * 3 {
                return currentKey // 保持当前调式
            }
        }
        
        return MusicKey(root: best.root, mode: best.mode, confidence: best.score)
    }
    
    private func calculateImprovedKeyScore(chroma: [Float], root: Int, mode: KeyMode) -> Float {
        let profile = mode.enhancedProfile
        var correlation: Float = 0
        var chromaMagnitude: Float = 0
        var profileMagnitude: Float = 0
        
        // 计算Pearson相关系数
        for i in 0..<12 {
            let rotatedIndex = (i + root) % 12
            correlation += chroma[i] * profile[rotatedIndex]
            chromaMagnitude += chroma[i] * chroma[i]
            profileMagnitude += profile[rotatedIndex] * profile[rotatedIndex]
        }
        
        let magnitude = sqrt(chromaMagnitude * profileMagnitude)
        let normalizedCorrelation = magnitude > 0 ? correlation / magnitude : 0
        
        // 额外奖励强调主音和属音
        let tonicStrength = chroma[root]
        let dominantStrength = chroma[(root + 7) % 12]
        let tonalBonus = (tonicStrength + dominantStrength * 0.7) * 0.3
        
        return normalizedCorrelation + tonalBonus
    }
    
    private func calculateKeyStability(newKey: (Int, KeyMode), oldKey: (Int, KeyMode)) -> Float {
        // 相同调式：稳定性最高
        if newKey.0 == oldKey.0 && newKey.1 == oldKey.1 {
            return 1.0
        }
        
        // 相关调式（相对大小调）
        if (newKey.1 != oldKey.1) {
            let relativeDistance = (newKey.0 - oldKey.0 + 12) % 12
            if (newKey.1 == .major && oldKey.1 == .minor && relativeDistance == 3) ||
               (newKey.1 == .minor && oldKey.1 == .major && relativeDistance == 9) {
                return 0.8
            }
        }
        
        // 五度圈距离
        let circleDistance = min((newKey.0 - oldKey.0 + 12) % 12, (oldKey.0 - newKey.0 + 12) % 12)
        if circleDistance <= 1 {
            return 0.7
        } else if circleDistance <= 2 {
            return 0.5
        }
        
        return 0.3
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
        case .minor, .diminished:
            numeral = numeral.lowercased()
        case .major7:
            numeral += "maj7"
        case .minor7:
            numeral += "7"
        case .dominant7:
            numeral += "7"
        default:
            break
        }
        
        return numeral
    }
    
    private func getRecentChordProgression() -> [ChordDetection] {
        return Array(chordHistory.suffix(min(8, chordHistory.count)))
    }
    
    // MARK: - Essentia 集成方法
    
    /// 检查 Essentia 服务可用性
    func checkEssentiaAvailability() async {
        essentiaAvailable = await essentiaClient.isServiceAvailable()
        print("🔧 Essentia 服务状态: \(essentiaAvailable ? "可用" : "不可用")")
    }
    
    /// 使用 Essentia 增强分析结果
    private func enhanceWithEssentia(fileURL: URL) async {
        guard essentiaAvailable else { return }
        
        // 检查缓存
        let cacheKey = fileURL.lastPathComponent
        if let cachedResult = essentiaResultCache[cacheKey] {
            lastEssentiaResult = cachedResult
            print("📂 使用缓存的 Essentia 结果")
            return
        }
        
        do {
            let result = try await essentiaClient.analyzeAudio(fileURL: fileURL)
            lastEssentiaResult = result
            essentiaResultCache[cacheKey] = result
            
            // 限制缓存大小
            if essentiaResultCache.count > 10 {
                let oldestKey = essentiaResultCache.keys.first!
                essentiaResultCache.removeValue(forKey: oldestKey)
            }
            
            print("✅ Essentia 分析完成并缓存")
        } catch {
            print("❌ Essentia 分析失败: \(error)")
            essentiaAvailable = false
        }
    }
    
    /// 合并本地分析和 Essentia 结果
    private func mergeResults(local: MusicAnalysisResult, essentia: EssentiaAnalysisResult) -> MusicAnalysisResult {
        // 使用 Essentia 的 BPM 和调性（如果质量较高）
        let enhancedBeat: BeatInfo
        let enhancedKey: MusicKey?
        
        // BPM 合并策略
        if essentia.rhythmAnalysis.qualityScore > 0.6 {
            enhancedBeat = BeatInfo(
                bpm: Float(essentia.rhythmAnalysis.bpm),
                timeSignature: local.beat.timeSignature,
                confidence: Float(essentia.rhythmAnalysis.confidence),
                beatPosition: local.beat.beatPosition, // 保持实时位置
                measurePosition: local.beat.measurePosition
            )
            print("🎵 使用 Essentia BPM: \(essentia.rhythmAnalysis.bpm)")
        } else {
            enhancedBeat = local.beat
            print("🎵 使用本地 BPM: \(local.beat.bpm)")
        }
        
        // 调性合并策略
        if essentia.keyAnalysis.strength > 0.4 {
            let keyRoot = parseKeyString(essentia.keyAnalysis.key)
            let keyMode: KeyMode = essentia.keyAnalysis.scale.lowercased() == "major" ? .major : .minor
            enhancedKey = MusicKey(
                root: keyRoot,
                mode: keyMode,
                confidence: Float(essentia.keyAnalysis.strength)
            )
            print("🎼 使用 Essentia 调性: \(essentia.keyAnalysis.key) \(essentia.keyAnalysis.scale)")
        } else {
            enhancedKey = local.key
            if let key = local.key {
                print("🎼 使用本地调性: \(noteNames[key.root]) \(key.mode.rawValue)")
            }
        }
        
        return MusicAnalysisResult(
            key: enhancedKey,
            chord: local.chord, // 保持实时和弦检测
            beat: enhancedBeat,
            chordProgression: local.chordProgression
        )
    }
    
    /// 解析调性字符串为数字索引
    private func parseKeyString(_ keyString: String) -> Int {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return noteNames.firstIndex(of: keyString) ?? 0
    }
    
    /// 启用/禁用混合分析
    func setHybridAnalysis(enabled: Bool) {
        useHybridAnalysis = enabled
        print("🔧 混合分析: \(enabled ? "启用" : "禁用")")
    }
    
    /// 清除 Essentia 缓存
    func clearEssentiaCache() {
        essentiaResultCache.removeAll()
        lastEssentiaResult = nil
        print("🗑️ Essentia 缓存已清除")
    }
    
    /// 获取 Essentia 分析统计
    func getEssentiaStats() -> (available: Bool, cacheCount: Int, lastResult: String?) {
        let lastResultInfo = lastEssentiaResult.map { result in
            "BPM: \(result.rhythmAnalysis.bpm), Key: \(result.keyAnalysis.key) \(result.keyAnalysis.scale)"
        }
        return (essentiaAvailable, essentiaResultCache.count, lastResultInfo)
    }
}

// MARK: - 辅助常量
// MARK: - Beat Tracker类
class BeatTracker {
    private var beatTimes: [Double] = []
    private var tempoEstimate: Float = 0  // 初始为0
    private var confidence: Float = 0
    private var phase: Float = 0
    private let minTempo: Float = 60
    private let maxTempo: Float = 200
    private var hasValidTempo: Bool = false
    
    func track(onsetStrengths: [Float], currentTime: Double) -> BeatInfo {
        // 使用autocorrelation找tempo
        let tempo = estimateTempo(onsetStrengths: onsetStrengths)
        
        // 只在检测到有效tempo时更新估计值
        if tempo > 0 {
            if hasValidTempo {
                // 平滑tempo估计 - 降低平滑因子，让BPM更快响应变化
                tempoEstimate = tempoEstimate * 0.7 + tempo * 0.3
            } else {
                tempoEstimate = tempo
                hasValidTempo = true
            }
        }
        
        // 找beat位置
        let beatPositions = findBeats(onsetStrengths: onsetStrengths, tempo: tempoEstimate)
        
        // 更新confidence
        updateConfidence(beatPositions: beatPositions, onsetStrengths: onsetStrengths)
        
        // 计算当前phase
        let beatPeriod = 60.0 / Double(tempoEstimate)
        phase = Float((currentTime.truncatingRemainder(dividingBy: beatPeriod)) / beatPeriod)
        
        // 计算小节位置
        let measurePosition = Int((currentTime / beatPeriod).truncatingRemainder(dividingBy: 4)) + 1
        
        return BeatInfo(
            bpm: hasValidTempo ? tempoEstimate : 0,
            timeSignature: TimeSignature(numerator: 4, denominator: 4),
            confidence: confidence,
            beatPosition: phase,
            measurePosition: measurePosition
        )
    }
    
    private func estimateTempo(onsetStrengths: [Float]) -> Float {
        let windowSize = min(onsetStrengths.count, 50)  // 从100降低到50
        let recentOnsets = Array(onsetStrengths.suffix(windowSize))
        
        guard recentOnsets.count > 3 else {  // 从5降到3，让检测更快开始
            print("⏳ Waiting for more onset data for tempo detection (current: \(recentOnsets.count))...")
            return 0  // 数据不足，返回0
        }
        
        // Autocorrelation for tempo estimation - 添加边界检查
        var maxCorrelation: Float = 0
        var bestTempo: Float = 0
        let sampleRate = 44100.0 / 1024.0 // onset rate 定义在这里
        
        print("🎵 Tempo estimation: data count=\(recentOnsets.count), min tempo=\(minTempo), max tempo=\(maxTempo)")
        
        // 计算合理的tempo范围
        let minTempoSamples = Int(sampleRate * 60 / Double(maxTempo))
        let maxTempoSamples = Int(sampleRate * 60 / Double(minTempo))
        let safeMaxSamples = min(maxTempoSamples, recentOnsets.count - 1)  // 确保不越界
        
        print("🎵 Tempo samples range: min=\(minTempoSamples), max=\(maxTempoSamples), safe max=\(safeMaxSamples)")
        
        // 确保范围有效：minTempoSamples必须小于等于safeMaxSamples
        guard minTempoSamples <= safeMaxSamples else {
            print("⚠️ Invalid tempo range: min=\(minTempoSamples), max=\(safeMaxSamples), data count=\(recentOnsets.count)")
            return 0  // 数据不足以进行tempo检测
        }
        
        // 测试不同的tempo（以samples为单位的间隔）
        for tempoSamples in minTempoSamples...safeMaxSamples {
            var correlation: Float = 0
            var count = 0
            
            // 确保有足够的重叠样本
            let maxI = recentOnsets.count - tempoSamples
            guard maxI > 0 else { continue }
            
            for i in 0..<maxI {
                correlation += recentOnsets[i] * recentOnsets[i + tempoSamples]
                count += 1
            }
            
            if count > 0 {
                correlation /= Float(count)
                if correlation > maxCorrelation {
                    maxCorrelation = correlation
                    bestTempo = Float(60.0 * sampleRate / Double(tempoSamples))
                }
            }
        }
        
        // 只有相关性足够高时才返回结果 - 降低阈值
        return maxCorrelation > 0.05 ? bestTempo : 0  // 从0.1降到0.05
    }
    
    private func findBeats(onsetStrengths: [Float], tempo: Float) -> [Int] {
        var beats: [Int] = []
        
        guard onsetStrengths.count >= 3 else {
            return beats  // 数据不足，返回空数组
        }
        
        // 简单的峰值检测
        for i in 1..<(onsetStrengths.count - 1) {
            if onsetStrengths[i] > onsetStrengths[i-1] && 
               onsetStrengths[i] > onsetStrengths[i+1] &&
               onsetStrengths[i] > 0.1 {
                beats.append(i)
            }
        }
        
        return beats
    }
    
    private func updateConfidence(beatPositions: [Int], onsetStrengths: [Float]) {
        guard !beatPositions.isEmpty else {
            confidence = confidence * 0.95
            return
        }
        
        guard beatPositions.count > 1 else {
            confidence = confidence * 0.9  // 只有一个beat，降低置信度
            return
        }
        
        // 计算beat和onset的对齐程度
        var alignment: Float = 0
        let beatInterval = Int(44100.0 / 1024.0 * 60.0 / Double(tempoEstimate))
        
        let comparisonCount = min(beatPositions.count - 1, 10)
        for i in 0..<comparisonCount {
            let predictedNext = beatPositions[i] + beatInterval
            let actualNext = beatPositions[i+1]
            let error = abs(predictedNext - actualNext)
            alignment += max(0, 1.0 - Float(error) / Float(beatInterval))
        }
        
        if comparisonCount > 0 {
            alignment /= Float(comparisonCount)
        }
        
        // 平滑confidence更新
        confidence = confidence * 0.8 + alignment * 0.2
        confidence = max(0, min(1, confidence))
    }
}

private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

// MARK: - 分析结果
struct MusicAnalysisResult {
    let key: MusicKey?
    let chord: ChordDetection?
    let beat: BeatInfo
    let chordProgression: [ChordDetection]
}