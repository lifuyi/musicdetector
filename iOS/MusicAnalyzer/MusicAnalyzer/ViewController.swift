import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    // MARK: - UI Components
    @IBOutlet weak var keyLabel: UILabel!
    @IBOutlet weak var chordLabel: UILabel!
    @IBOutlet weak var romanNumeralLabel: UILabel!
    @IBOutlet weak var bpmLabel: UILabel!
    @IBOutlet weak var timeSignatureLabel: UILabel!
    @IBOutlet weak var measurePositionLabel: UILabel!
    @IBOutlet weak var confidenceProgressView: UIProgressView!
    @IBOutlet weak var chordProgressionTextView: UITextView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var loadFileButton: UIButton!
    @IBOutlet weak var urlTextField: UITextField!
    @IBOutlet weak var playURLButton: UIButton!
    
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
    }
    
    // MARK: - Setup
    private func setupComponents() {
        audioInputManager = AudioInputManager()
        audioInputManager.delegate = self
        
        audioProcessor = AudioProcessor()
        musicAnalysisEngine = MusicAnalysisEngine()
    }
    
    private func setupUI() {
        title = "音乐分析器"
        
        // 设置初始状态
        keyLabel.text = "调式: 检测中..."
        chordLabel.text = "和弦: --"
        romanNumeralLabel.text = "级数: --"
        bpmLabel.text = "BPM: --"
        timeSignatureLabel.text = "拍号: 4/4"
        measurePositionLabel.text = "拍子: --"
        
        confidenceProgressView.progress = 0.0
        chordProgressionTextView.text = "和弦进行将在这里显示..."
        
        // 按钮样式
        recordButton.setTitle("开始录音", for: .normal)
        recordButton.backgroundColor = .systemRed
        recordButton.layer.cornerRadius = 8
        recordButton.setTitleColor(.white, for: .normal)
        
        loadFileButton.backgroundColor = .systemBlue
        loadFileButton.layer.cornerRadius = 8
        loadFileButton.setTitleColor(.white, for: .normal)
        
        playURLButton.backgroundColor = .systemGreen
        playURLButton.layer.cornerRadius = 8
        playURLButton.setTitleColor(.white, for: .normal)
        
        urlTextField.placeholder = "输入音频URL..."
        urlTextField.borderStyle = .roundedRect
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if !granted {
                    self.showAlert(title: "需要麦克风权限", message: "请在设置中允许访问麦克风以进行实时音频分析")
                }
            }
        }
    }
    
    // MARK: - Actions
    @IBAction func recordButtonTapped(_ sender: UIButton) {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    @IBAction func loadFileButtonTapped(_ sender: UIButton) {
        presentDocumentPicker()
    }
    
    @IBAction func playURLButtonTapped(_ sender: UIButton) {
        guard let urlString = urlTextField.text,
              !urlString.isEmpty,
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
            recordButton.setTitle("停止录音", for: .normal)
            recordButton.backgroundColor = .systemGray
        } catch {
            showAlert(title: "录音失败", message: error.localizedDescription)
        }
    }
    
    private func stopRecording() {
        audioInputManager.stopMicrophoneInput()
        isRecording = false
        recordButton.setTitle("开始录音", for: .normal)
        recordButton.backgroundColor = .systemRed
    }
    
    private func presentDocumentPicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }
    
    private func playAudioFromURL(_ url: URL) {
        // 停止当前录音
        if isRecording {
            stopRecording()
        }
        
        audioInputManager.playAudioFromURL(url)
    }
    
    // MARK: - UI Updates
    private func updateUI(with result: MusicAnalysisResult) {
        DispatchQueue.main.async {
            // 更新调式信息
            if let key = result.key {
                let keyString = self.noteNames[key.root] + key.mode.rawValue
                self.keyLabel.text = "调式: \(keyString)"
                self.confidenceProgressView.progress = key.confidence
            } else {
                self.keyLabel.text = "调式: 检测中..."
                self.confidenceProgressView.progress = 0.0
            }
            
            // 更新和弦信息
            if let chord = result.chord {
                let chordString = self.noteNames[chord.root] + chord.quality.rawValue
                self.chordLabel.text = "和弦: \(chordString)"
                self.romanNumeralLabel.text = "级数: \(chord.romanNumeral)"
            } else {
                self.chordLabel.text = "和弦: --"
                self.romanNumeralLabel.text = "级数: --"
            }
            
            // 更新节拍信息
            let beat = result.beat
            self.bpmLabel.text = "BPM: \(Int(beat.bpm))"
            self.timeSignatureLabel.text = "拍号: \(beat.timeSignature.description)"
            self.measurePositionLabel.text = "拍子: \(beat.measurePosition)/\(beat.timeSignature.numerator)"
            
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
        
        chordProgressionTextView.text = progressionText
        
        // 自动滚动到底部
        let range = NSMakeRange(chordProgressionTextView.text.count - 1, 0)
        chordProgressionTextView.scrollRangeToVisible(range)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
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

// MARK: - UIDocumentPickerDelegate
extension ViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // 停止当前录音
        if isRecording {
            stopRecording()
        }
        
        do {
            try audioInputManager.playAudioFile(url: url)
        } catch {
            showAlert(title: "文件播放失败", message: error.localizedDescription)
        }
    }
}

// MARK: - Constants
private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]