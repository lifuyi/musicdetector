import Cocoa
import AVFoundation

class ViewController: NSViewController {
    
    // MARK: - UI Components
    @IBOutlet weak var keyLabel: NSTextField!
    @IBOutlet weak var chordLabel: NSTextField!
    @IBOutlet weak var romanNumeralLabel: NSTextField!
    @IBOutlet weak var bpmLabel: NSTextField!
    @IBOutlet weak var timeSignatureLabel: NSTextField!
    @IBOutlet weak var measurePositionLabel: NSTextField!
    @IBOutlet weak var confidenceProgressView: NSProgressIndicator!
    @IBOutlet weak var chordProgressionTextView: NSTextView!
    @IBOutlet weak var recordButton: NSButton!
    @IBOutlet weak var loadFileButton: NSButton!
    @IBOutlet weak var urlTextField: NSTextField!
    @IBOutlet weak var playURLButton: NSButton!
    
    // MARK: - Core Components
    private var audioInputManager: AudioInputManager!
    private var audioProcessor: AudioProcessor!
    private var musicAnalysisEngine: MusicAnalysisEngine!
    
    // MARK: - State
    private var isRecording = false
    private var analysisResults: [MusicAnalysisResult] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupComponents()
        setupUI()
        requestMicrophonePermission()
        
        // 🎵 初始化 Essentia 集成
        Task {
            await musicAnalysisEngine.checkEssentiaAvailability()
        }
        musicAnalysisEngine.setHybridAnalysis(enabled: true)
    }
    
    // MARK: - Setup
    private func setupComponents() {
        audioInputManager = AudioInputManager()
        audioInputManager.delegate = self
        
        audioProcessor = AudioProcessor()
        musicAnalysisEngine = MusicAnalysisEngine()
    }
    
    private func setupUI() {
        view.window?.title = "音乐分析器"
        
        // 设置初始状态
        keyLabel.stringValue = "调式: 检测中..."
        chordLabel.stringValue = "和弦: --"
        romanNumeralLabel.stringValue = "级数: --"
        bpmLabel.stringValue = "BPM: --"
        timeSignatureLabel.stringValue = "拍号: 4/4"
        measurePositionLabel.stringValue = "拍子: --"
        
        confidenceProgressView.doubleValue = 0.0
        confidenceProgressView.style = .bar
        chordProgressionTextView.string = "和弦进行将在这里显示..."
        
        // 按钮样式
        recordButton.title = "开始录音"
        recordButton.bezelStyle = .rounded
        
        loadFileButton.title = "加载文件"
        loadFileButton.bezelStyle = .rounded
        
        playURLButton.title = "播放URL"
        playURLButton.bezelStyle = .rounded
        
        urlTextField.placeholderString = "输入音频URL..."
    }
    
    private func requestMicrophonePermission() {
        // macOS handles microphone permissions through system preferences and entitlements
        // No need for explicit permission request like iOS
        print("麦克风权限检查 - macOS通过系统偏好设置管理")
    }
    
    // MARK: - Actions
    @IBAction func recordButtonTapped(_ sender: NSButton) {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    @IBAction func loadFileButtonTapped(_ sender: NSButton) {
        presentDocumentPicker()
    }
    
    // 🎵 新增 Essentia 文件分析按钮
    @IBAction func analyzeWithEssentiaButtonTapped(_ sender: NSButton) {
        presentEssentiaAnalysisPicker()
    }
    
    @IBAction func playURLButtonTapped(_ sender: NSButton) {
        let urlString = urlTextField.stringValue
        guard !urlString.isEmpty,
              let url = URL(string: urlString) else {
            showAlert(title: "无效URL", message: "请输入有效的音频URL")
            return
        }
        
        playAudioFromURL(url)
    }
    
    // MARK: - Audio Control
    private func startRecording() {
        do {
            try audioInputManager.startMicrophoneInput()
            isRecording = true
            recordButton.title = "停止录音"
        } catch {
            showAlert(title: "录音失败", message: error.localizedDescription)
        }
    }
    
    private func stopRecording() {
        audioInputManager.stopMicrophoneInput()
        isRecording = false
        recordButton.title = "开始录音"
    }
    
    private func presentDocumentPicker() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.audio]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                self.playAudioFile(url: url)
            }
        }
    }
    
    private func playAudioFromURL(_ url: URL) {
        // 停止当前录音
        if isRecording {
            stopRecording()
        }
        
        audioInputManager.playAudioFromURL(url)
    }
    
    private func playAudioFile(url: URL) {
        // 停止当前录音
        if isRecording {
            stopRecording()
        }
        
        do {
            try audioInputManager.playAudioFile(url: url)
        } catch {
            showAlert(title: "播放失败", message: error.localizedDescription)
        }
    }
    
    // MARK: - UI Updates
    private func updateUI(with result: MusicAnalysisResult) {
        DispatchQueue.main.async {
            // 更新调式信息
            if let key = result.key {
                let keyString = noteNames[key.root] + key.mode.rawValue
                self.keyLabel.stringValue = "调式: \(keyString)"
                self.confidenceProgressView.doubleValue = Double(key.confidence)
            } else {
                self.keyLabel.stringValue = "调式: 检测中..."
                self.confidenceProgressView.doubleValue = 0.0
            }
            
            // 更新和弦信息
            if let chord = result.chord {
                let chordString = noteNames[chord.root] + chord.quality.rawValue
                self.chordLabel.stringValue = "和弦: \(chordString)"
                self.romanNumeralLabel.stringValue = "级数: \(chord.romanNumeral)"
            } else {
                self.chordLabel.stringValue = "和弦: --"
                self.romanNumeralLabel.stringValue = "级数: --"
            }
            
            // 更新节拍信息
            let beat = result.beat
            if beat.bpm > 0 {
                self.bpmLabel.stringValue = "BPM: \(Int(beat.bpm))"
            } else {
                self.bpmLabel.stringValue = "BPM: 检测中..."
            }
            self.timeSignatureLabel.stringValue = "拍号: \(beat.timeSignature.description)"
            self.measurePositionLabel.stringValue = "拍子: \(beat.measurePosition)/\(beat.timeSignature.numerator)"
            
            // 更新和弦进行
            self.updateChordProgression(result.chordProgression)
        }
    }
    
    private func updateChordProgression(_ chords: [ChordDetection]) {
        var progressionText = "和弦进行:\n"
        
        for (index, chord) in chords.enumerated() {
            let chordName = noteNames[chord.root] + chord.quality.rawValue
            progressionText += "\(chordName) (\(chord.romanNumeral))"
            
            if index < chords.count - 1 {
                progressionText += " → "
            }
            
            // 每4个和弦换行
            if (index + 1) % 4 == 0 {
                progressionText += "\n"
            }
        }
        
        chordProgressionTextView.string = progressionText
        
        // 自动滚动到底部 - 修复边界问题
        let textLength = chordProgressionTextView.string.count
        if textLength > 0 {
            let range = NSMakeRange(textLength - 1, 0)
            chordProgressionTextView.scrollRangeToVisible(range)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    // MARK: - 🎵 Essentia Integration
    
    private func presentEssentiaAnalysisPicker() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.mp3, .wav, .aiff, .m4a, 
                                       UTType(filenameExtension: "flac") ?? .audio]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.title = "选择音频文件进行 Essentia 高精度分析"
        openPanel.message = "Essentia 将提供专业级的 BPM 和调性检测"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                Task {
                    await self.performEssentiaAnalysis(fileURL: url)
                }
            }
        }
    }
    
    private func performEssentiaAnalysis(fileURL: URL) async {
        print("🎵 开始 Essentia 高精度分析: \(fileURL.lastPathComponent)")
        
        // 显示分析开始提示
        DispatchQueue.main.async {
            self.keyLabel.stringValue = "调式: Essentia 分析中..."
            self.bpmLabel.stringValue = "BPM: Essentia 分析中..."
        }
        
        do {
            let result = try await EssentiaAPIClient.shared.analyzeAudio(fileURL: fileURL)
            
            DispatchQueue.main.async {
                self.displayEssentiaResult(result, fileName: fileURL.lastPathComponent)
            }
        } catch {
            print("❌ Essentia 分析失败: \(error)")
            DispatchQueue.main.async {
                self.showAlert(title: "Essentia 分析失败", 
                             message: "错误: \(error.localizedDescription)\n\n请确保 API 服务正在运行")
                
                // 恢复原始状态
                self.keyLabel.stringValue = "调式: 检测中..."
                self.bpmLabel.stringValue = "BPM: 检测中..."
            }
        }
    }
    
    private func displayEssentiaResult(_ result: EssentiaAnalysisResult, fileName: String) {
        // 更新主要 UI 元素
        bpmLabel.stringValue = "BPM: \(String(format: "%.1f", result.rhythmAnalysis.bpm)) (Essentia)"
        keyLabel.stringValue = "调性: \(result.keyAnalysis.key) \(result.keyAnalysis.scale) (Essentia)"
        
        // 设置置信度进度条
        confidenceProgressView.doubleValue = Double(result.keyAnalysis.strength)
        
        // 构建详细信息
        let message = """
        🎵 Essentia 专业分析结果
        文件: \(fileName)
        
        🎼 调性分析:
        • 检测结果: \(result.keyAnalysis.key) \(result.keyAnalysis.scale)
        • 强度: \(String(format: "%.3f", result.keyAnalysis.strength))
        • 置信度等级: \(result.keyAnalysis.confidenceLevel)
        • 算法: \(result.keyAnalysis.algorithm)
        
        🥁 节拍分析:
        • BPM: \(String(format: "%.1f", result.rhythmAnalysis.bpm))
        • 原始 BPM: \(String(format: "%.1f", result.rhythmAnalysis.bpmRaw))
        • 质量分数: \(String(format: "%.3f", result.rhythmAnalysis.qualityScore))
        • 音频时长: \(String(format: "%.1f", result.rhythmAnalysis.audioDuration))秒
        
        📊 分析质量:
        • 整体质量: \(String(format: "%.3f", result.overallQuality))
        • 处理时间: \(String(format: "%.2f", result.processingTime ?? 0))秒
        • 使用建议: \(result.recommendedUse)
        
        🔬 算法对比:
        """
        
        var detailedMessage = message
        
        // 添加算法对比信息
        for (algorithm, alternative) in result.keyAnalysis.alternatives {
            detailedMessage += "\n• \(algorithm): \(alternative.key) \(alternative.scale) (强度: \(String(format: "%.3f", alternative.strength)))"
        }
        
        // 显示详细结果弹窗
        let alert = NSAlert()
        alert.messageText = "🎵 Essentia 分析完成"
        alert.informativeText = detailedMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: "太棒了！")
        alert.addButton(withTitle: "复制结果")
        
        let response = alert.runModal()
        
        // 如果用户选择复制结果
        if response == .alertSecondButtonReturn {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(detailedMessage, forType: .string)
            
            // 显示复制成功提示
            let copyAlert = NSAlert()
            copyAlert.messageText = "已复制到剪贴板"
            copyAlert.informativeText = "分析结果已复制到剪贴板"
            copyAlert.alertStyle = .informational
            copyAlert.runModal()
        }
        
        // 获取 Essentia 统计信息并打印
        let stats = musicAnalysisEngine.getEssentiaStats()
        print("📊 Essentia 统计: 可用=\(stats.available), 缓存=\(stats.cacheCount), 最新=\(stats.lastResult ?? "无")")
    }
    
    // 添加清除 Essentia 缓存的功能
    @IBAction func clearEssentiaCacheButtonTapped(_ sender: NSButton) {
        musicAnalysisEngine.clearEssentiaCache()
        showAlert(title: "缓存已清除", message: "Essentia 分析缓存已清除")
    }
    
    // 添加检查 Essentia 状态的功能
    @IBAction func checkEssentiaStatusButtonTapped(_ sender: NSButton) {
        Task {
            let available = await EssentiaAPIClient.shared.isServiceAvailable()
            let supportedFormats = await EssentiaAPIClient.shared.getSupportedFormats()
            
            DispatchQueue.main.async {
                let statusMessage = """
                🔧 Essentia 服务状态:
                
                • 服务可用: \(available ? "✅ 是" : "❌ 否")
                • 支持格式: \(supportedFormats.joined(separator: ", "))
                • 服务地址: http://localhost:10814
                
                \(available ? "✅ 一切正常，可以使用 Essentia 分析！" : "⚠️ 请检查 API 服务是否启动")
                """
                
                self.showAlert(title: "Essentia 状态检查", message: statusMessage)
            }
        }
    }
}

// MARK: - AudioInputDelegate
extension ViewController: AudioInputDelegate {
    func didReceiveAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // 在后台队列处理音频
        DispatchQueue.global(qos: .userInitiated).async {
            guard let features = self.audioProcessor.processAudioBuffer(buffer) else { return }
            
            let result = self.musicAnalysisEngine.analyze(features)
            self.analysisResults.append(result)
            
            // 保持结果历史在合理范围内
            if self.analysisResults.count > 1000 {
                self.analysisResults.removeFirst(500)
            }
            
            // 更新UI
            self.updateUI(with: result)
        }
    }
    
    func didEncounterError(_ error: Error) {
        DispatchQueue.main.async {
            self.showAlert(title: "音频处理错误", message: error.localizedDescription)
        }
    }
}


// MARK: - Constants
private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]