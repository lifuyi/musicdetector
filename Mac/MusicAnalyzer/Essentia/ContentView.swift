//
//  ContentView.swift
//  主界面
//

import SwiftUI

struct ContentView: View {
    @State private var selectedFile: URL?
    @State private var analysisResult: AudioAnalysisResult?
    @State private var isAnalyzing = false
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 标题区域
                HeaderView()
                
                // 文件选择区域
                FileSelectionView(
                    selectedFile: $selectedFile,
                    showingFilePicker: $showingFilePicker
                )
                
                // 分析按钮
                AnalyzeButton(
                    isAnalyzing: $isAnalyzing,
                    selectedFile: selectedFile,
                    onAnalyze: analyzeAudio
                )
                
                // 结果显示
                if isAnalyzing {
                    ProgressView("分析中...")
                        .padding()
                } else if let result = analysisResult {
                    ResultsView(result: result)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Essentia 音频分析")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(selectedURL: $selectedFile)
            }
        }
    }
    
    private func analyzeAudio() {
        guard let fileURL = selectedFile else { return }
        
        isAnalyzing = true
        analysisResult = nil
        
        // 异步分析
        AudioAnalyzer.shared.analyzeAudioFileAsync(at: fileURL) { result in
            DispatchQueue.main.async {
                self.analysisResult = result
                self.isAnalyzing = false
                
                if result == nil {
                    print("分析失败")
                }
            }
        }
    }
}

// MARK: - 子视图

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Essentia 音频分析")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("BPM 检测 • 调性分析")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical)
    }
}

struct FileSelectionView: View {
    @Binding var selectedFile: URL?
    @Binding var showingFilePicker: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            if let fileURL = selectedFile {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fileURL.lastPathComponent)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(fileURL.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: { selectedFile = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            } else {
                Button(action: { showingFilePicker = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("选择音频文件")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
            }
        }
    }
}

struct AnalyzeButton: View {
    @Binding var isAnalyzing: Bool
    let selectedFile: URL?
    let onAnalyze: () -> Void
    
    var body: some View {
        Button(action: onAnalyze) {
            if isAnalyzing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(width: 120, height: 50)
            } else {
                Text("开始分析")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 120, height: 50)
            }
        }
        .background(selectedFile != nil ? Color.green : Color.gray)
        .cornerRadius(25)
        .disabled(selectedFile == nil || isAnalyzing)
        .animation(.easeInOut, value: isAnalyzing)
    }
}

struct ResultsView: View {
    let result: AudioAnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("分析完成")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ResultRow(icon: "timer", title: "BPM", value: String(format: "%.1f", result.bpm))
                ResultRow(icon: "music.note", title: "调性", value: "\(result.key) \(result.scale)")
                ResultRow(icon: "percent", title: "置信度", value: String(format: "%.1f%%", result.confidence * 100))
                
                if !result.isValid {
                    Label("置信度较低，结果可能不准确", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(.vertical)
    }
}

struct ResultRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.blue)
            
            Text(title)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
}

// MARK: - 文件选择器

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.selectedURL = urls.first
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
