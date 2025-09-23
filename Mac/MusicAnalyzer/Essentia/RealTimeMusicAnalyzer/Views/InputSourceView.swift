//
//  InputSourceView.swift
//  UI for selecting and managing different audio input sources
//

import SwiftUI
import UniformTypeIdentifiers

struct InputSourceView: View {
    @ObservedObject var inputManager: AudioInputManager
    @ObservedObject var analysisEngine: RealTimeAnalysisEngine
    
    @State private var showingFilePicker = false
    @State private var showingURLInput = false
    @State private var urlString = ""
    @State private var selectedInputType: InputType = .microphone
    
    enum InputType: String, CaseIterable {
        case microphone = "Microphone"
        case file = "Audio File"
        case player = "Play & Analyze"
        case url = "URL Stream"
        
        var icon: String {
            switch self {
            case .microphone: return "mic.circle.fill"
            case .file: return "doc.circle.fill"
            case .player: return "play.circle.fill"
            case .url: return "globe.circle.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Audio Input Source")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Select your audio input method")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Input Type Selector
            HStack(spacing: 12) {
                ForEach(InputType.allCases, id: \.self) { inputType in
                    InputTypeButton(
                        inputType: inputType,
                        isSelected: selectedInputType == inputType,
                        action: { selectInputType(inputType) }
                    )
                }
            }
            
            Divider()
            
            // Current Source Info
            if inputManager.currentSource != .none {
                CurrentSourceCard(inputManager: inputManager)
            }
            
            // Input-specific controls
            switch selectedInputType {
            case .microphone:
                MicrophoneControls(inputManager: inputManager)
            case .file:
                FileInputControls(inputManager: inputManager, showingFilePicker: $showingFilePicker)
            case .player:
                Text("Audio Player with real-time analysis available in main interface")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            case .url:
                URLInputControls(
                    inputManager: inputManager,
                    urlString: $urlString,
                    showingURLInput: $showingURLInput
                )
            }
            
            // Processing Status
            if inputManager.isProcessing {
                ProcessingStatusView(inputManager: inputManager)
            }
            
            // Error Display
            if let errorMessage = inputManager.errorMessage {
                ErrorView(message: errorMessage) {
                    inputManager.errorMessage = nil
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .sheet(isPresented: $showingFilePicker) {
            AudioFilePicker { url in
                inputManager.processAudioFile(url)
            }
        }
        .sheet(isPresented: $showingURLInput) {
            URLInputSheet(urlString: $urlString) { url in
                inputManager.processAudioFromURL(url)
            }
        }
        .onAppear {
            setupInputManager()
        }
    }
    
    private func selectInputType(_ type: InputType) {
        selectedInputType = type
        inputManager.stopAllInputs()
        analysisEngine.stopAnalysis()
    }
    
    private func setupInputManager() {
        inputManager.onAudioData = { audioBuffer in
            analysisEngine.processAudioData(audioBuffer)
        }
        
        inputManager.onAnalysisComplete = { result in
            // Handle immediate analysis results for file/URL processing
            if let result = result {
                print("Analysis result: \(result.description)")
            }
        }
    }
}

// MARK: - Input Type Button

struct InputTypeButton: View {
    let inputType: InputSourceView.InputType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: inputType.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(inputType.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 80, height: 70)
            .background(isSelected ? Color.blue : Color.secondary.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Current Source Card

struct CurrentSourceCard: View {
    @ObservedObject var inputManager: AudioInputManager
    
    var body: some View {
        HStack {
            Image(systemName: sourceIcon)
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Current Source")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(inputManager.getInputSourceDescription())
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Control buttons
            HStack(spacing: 8) {
                if inputManager.isProcessing {
                    Button(action: inputManager.pauseProcessing) {
                        Image(systemName: "pause.circle.fill")
                            .foregroundColor(.orange)
                    }
                } else if inputManager.currentSource != .none {
                    Button(action: inputManager.resumeProcessing) {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                Button(action: inputManager.stopAllInputs) {
                    Image(systemName: "stop.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .font(.title3)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var sourceIcon: String {
        switch inputManager.currentSource {
        case .microphone: return "mic.fill"
        case .file: return "doc.fill"
        case .url: return "globe"
        case .none: return "questionmark"
        }
    }
}

// MARK: - Microphone Controls

struct MicrophoneControls: View {
    @ObservedObject var inputManager: AudioInputManager
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: inputManager.startMicrophoneInput) {
                HStack {
                    Image(systemName: "mic.circle.fill")
                    Text("Start Live Analysis")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.green)
                .cornerRadius(10)
            }
            
            // Audio level indicator
            AudioLevelIndicator(level: inputManager.audioLevel)
        }
    }
}

// MARK: - File Input Controls

struct FileInputControls: View {
    @ObservedObject var inputManager: AudioInputManager
    @Binding var showingFilePicker: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: { showingFilePicker = true }) {
                HStack {
                    Image(systemName: "folder.circle.fill")
                    Text("Select Audio File")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.blue)
                .cornerRadius(10)
            }
            
            // Supported formats
            Text("Supported formats: \(inputManager.getSupportedFormats().joined(separator: ", "))")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - URL Input Controls

struct URLInputControls: View {
    @ObservedObject var inputManager: AudioInputManager
    @Binding var urlString: String
    @Binding var showingURLInput: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: { showingURLInput = true }) {
                HStack {
                    Image(systemName: "link.circle.fill")
                    Text("Enter Audio URL")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.purple)
                .cornerRadius(10)
            }
            
            if !urlString.isEmpty {
                HStack {
                    Text("URL: \(urlString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button("Analyze") {
                        inputManager.processAudioFromURL(urlString)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Processing Status

struct ProcessingStatusView: View {
    @ObservedObject var inputManager: AudioInputManager
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Processing Audio...")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            if inputManager.downloadProgress > 0 && inputManager.downloadProgress < 1 {
                ProgressView(value: inputManager.downloadProgress) {
                    Text("Progress: \(Int(inputManager.downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button("Dismiss", action: onDismiss)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Audio Level Indicator

struct AudioLevelIndicator: View {
    let level: Float
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Audio Level")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 6)
                    .cornerRadius(3)
                
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.green, .yellow, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: CGFloat(level) * 200, height: 6)
                    .cornerRadius(3)
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
            .frame(width: 200)
        }
    }
}

// MARK: - File Picker

struct AudioFilePicker: View {
    let onFileSelected: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Audio File")
                .font(.title2)
                .fontWeight(.bold)
            
            Button("Choose File") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedContentTypes = [
                    .audio,
                    .mp3,
                    .wav,
                    .aiff,
                    .mpeg4Audio
                ]
                
                panel.begin { response in
                    if response == .OK, let url = panel.url {
                        onFileSelected(url)
                        dismiss()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            
            Text("Supported formats: MP3, WAV, M4A, AAC, FLAC, AIFF")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Selected files will be played and analyzed in real-time")
                .font(.caption)
                .foregroundColor(.blue)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(width: 300, height: 250)
    }
}

// MARK: - URL Input Sheet

struct URLInputSheet: View {
    @Binding var urlString: String
    let onURLSubmitted: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Enter Audio URL")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Audio URL:")
                        .font(.headline)
                    
                    TextField("https://example.com/audio.mp3", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                }
                
                Text("Supported: Direct links to audio files (MP3, WAV, AAC, etc.)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Analyze") {
                        onURLSubmitted(urlString)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlString.isEmpty || !isValidURL(urlString))
                }
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }
    
    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
}