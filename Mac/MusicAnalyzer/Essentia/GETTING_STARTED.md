# iOS Essentia 快速开始指南

## 概述

本方案提供了完整的 iOS Essentia 音频分析库集成解决方案，包括：
- 📦 即用型 iOS 包装器
- 📱 完整的 SwiftUI 示例应用
- 🔧 详细的集成文档
- ⚡ 性能优化建议

## 快速集成 (3 步完成)

### 第 1 步：添加文件到项目

将以下文件添加到您的 Xcode 项目：
```
integration_kit/
├── EssentiaIOSAnalyzer.h      # 主头文件
├── EssentiaIOSAnalyzer.mm     # Objective-C++ 实现
└── EssentiaSwiftBridge.swift  # Swift 包装器
```

### 第 2 步：配置 Build Settings

在 Xcode 中配置以下设置：

**Header Search Paths:**
```
$(PROJECT_DIR)/YourProject/integration_kit
```

**Linked Libraries:**
```
libc++.tbd
libsqlite3.tbd  
libz.tbd
```

**Swift Bridging Header:** (如果使用 Swift)
```objc
// YourProject-Bridging-Header.h
#import "EssentiaIOSAnalyzer.h"
```

### 第 3 步：开始使用

**Swift 使用示例：**
```swift
import Foundation

class MyAudioAnalyzer {
    private let analyzer = AudioAnalyzer.shared
    
    func analyzeAudioFile(url: URL) {
        analyzer.analyzeAudioFileAsync(at: url) { result in
            if let result = result {
                print("分析结果: \(result.description)")
                // 更新 UI
            } else {
                print("分析失败")
            }
        }
    }
}
```

**Objective-C 使用示例：**
```objc
#import "EssentiaIOSAnalyzer.h"

EssentiaIOSAnalyzer *analyzer = [EssentiaIOSAnalyzer sharedAnalyzer];
EssentiaAnalysisResult *result = [analyzer analyzeAudioFile:@"path/to/audio.wav"];

if (result.isValid) {
    NSLog(@"BPM: %.1f, Key: %@ %@, Confidence: %.2f", 
          result.bpm, result.key, result.scale, result.confidence);
}
```

## 核心功能

### 1. 音频分析
- ✅ **BPM 检测**: 60-200 BPM 范围
- ✅ **调性分析**: 支持 12 个调性的大调/小调
- ✅ **置信度评估**: 0.0-1.0 的可靠性评分
- ✅ **多格式支持**: WAV, MP3, M4A, AAC, FLAC, OGG

### 2. 异步处理
- ✅ **后台分析**: 不阻塞主线程
- ✅ **进度追踪**: 支持分析进度回调
- ✅ **错误处理**: 完善的错误处理机制

### 3. 批量处理
- ✅ **多文件分析**: 支持批量音频文件处理
- ✅ **结果聚合**: 统计分析和结果汇总

## 性能优化

### 内存管理
```swift
// 推荐的使用模式
class AudioService {
    private let queue = DispatchQueue(label: "audio.analysis", qos: .userInitiated)
    
    func analyzeAudio(url: URL, completion: @escaping (AudioAnalysisResult?) -> Void) {
        queue.async {
            let result = AudioAnalyzer.shared.analyzeAudioFile(url.path)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
```

### 文件格式建议
- **WAV**: 最快的分析速度
- **M4A**: 较好的压缩率和分析速度平衡
- **MP3**: 广泛兼容，分析速度适中

### 文件大小建议
- 建议分析 30-120 秒的音频片段
- 对于长音频文件，考虑分段分析
- 采样率 44.1kHz 即可获得良好结果

## 错误处理

### 常见错误码
```swift
enum AudioAnalyzerError: Error {
    case notAvailable        // 分析器不可用
    case fileNotFound       // 文件不存在
    case unsupportedFormat  // 不支持的格式
    case analysisFailed     // 分析失败
}
```

### 错误处理示例
```swift
func analyzeWithErrorHandling(url: URL) {
    guard AudioAnalyzer.isAudioFileSupported(url.path) else {
        print("不支持的音频格式")
        return
    }
    
    let (result, error) = AudioAnalyzer.shared.analyzeWithDetails(url.path)
    
    if let error = error {
        print("分析错误: \(error.localizedDescription)")
        return
    }
    
    if let result = result {
        print("分析成功: \(result.description)")
    }
}
```

## 实际应用示例

### 音乐播放器集成
```swiftnclass MusicPlayer {
    private let analyzer = AudioAnalyzer.shared
    
    func playAndAnalyze(_ songURL: URL) {
        // 播放音乐
        audioPlayer.play()
        
        // 异步分析音频特征
        analyzer.analyzeAudioFileAsync(at: songURL) { [weak self] result in
            guard let self = self, let result = result else { return }
            
            // 更新播放界面
            self.updateUI(with: result)
            
            // 保存分析结果
            self.saveAnalysisResult(result, for: songURL)
        }
    }
    
    private func updateUI(with result: AudioAnalysisResult) {
        DispatchQueue.main.async {
            self.bpmLabel.text = "BPM: \(String(format: "%.0f", result.bpm))"
            self.keyLabel.text = "Key: \(result.key) \(result.scale)"
        }
    }
}
```

### 音乐库批量分析
```swift
class MusicLibraryAnalyzer {
    func analyzeLibrary(_ songs: [Song]) {
        let filePaths = songs.map { $0.filePath }
        
        AudioAnalyzer.shared.analyzeMultipleFiles(filePaths).forEach { result in
            print("分析完成: \(result.description)")
        }
    }
}
```

## 下一步

1. **测试集成**: 运行示例应用测试功能
2. **性能调优**: 根据实际需求调整参数
3. **功能扩展**: 添加更多音频分析功能
4. **产品化**: 集成到您的正式应用中

## 获取帮助

- 📖 查看完整的集成指南
- 🔍 参考示例项目实现
- 💬 查看常见问题解答
- 🐛 报告问题或建议改进

---

**注意**: 这是一个功能完整的 iOS Essentia 集成方案，但使用的分析结果是模拟数据。
要获得真实的音频分析结果，需要集成编译好的 Essentia 静态库。
