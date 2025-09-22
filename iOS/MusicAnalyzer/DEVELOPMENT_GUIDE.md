# 音乐分析器开发指南

## 项目概述

这是一个iOS原生音乐分析应用，能够实时检测音乐的调式（key）和和弦进行，并显示和弦级数。应用优先考虑准确性和处理速度。

## 核心功能

### ✅ 已实现功能
1. **音频输入管理** - 支持麦克风、文件和URL输入
2. **实时音频处理** - 基于FFT的频谱分析
3. **特征提取** - 色彩特征、MFCC、Tonnetz等
4. **节拍检测** - BPM和拍号识别
5. **调式检测** - 使用Krumhansl-Schmuckler算法
6. **和弦识别** - 基于色彩匹配的和弦检测
7. **和弦级数显示** - 罗马数字标记法
8. **用户界面** - 实时显示分析结果

### 🔧 需要优化的部分

#### 1. 音频处理优化
```swift
// 在AudioProcessor.swift中优化FFT性能
// 考虑使用更大的窗口大小来提高频率分辨率
private let fftSize: Int = 4096  // 从2048增加到4096
private let hopSize: Int = 1024  // 相应调整hop size

// 添加预加重滤波器提高高频精度
private func preEmphasis(_ samples: [Float]) -> [Float] {
    var output = samples
    for i in 1..<samples.count {
        output[i] = samples[i] - 0.97 * samples[i-1]
    }
    return output
}
```

#### 2. 和弦检测精度提升
```swift
// 在MusicAnalysisEngine.swift中改进和弦检测
private func enhancedChordDetection(_ features: AudioFeatures) -> ChordDetection? {
    // 1. 添加和弦转位检测
    // 2. 考虑上下文信息（前一个和弦）
    // 3. 使用更复杂的评分算法
    // 4. 添加七和弦、九和弦等扩展和弦支持
}
```

#### 3. 节拍检测改进
```swift
// 添加自适应节拍跟踪
private func adaptiveBeatTracking(_ features: AudioFeatures) -> BeatInfo {
    // 1. 使用onset detection
    // 2. 实现beat tracking算法
    // 3. 添加tempo变化检测
    // 4. 支持复杂拍号识别
}
```

## 性能优化建议

### 1. 内存管理
- 使用对象池减少频繁内存分配
- 实现音频缓冲区复用
- 优化FFT计算的内存使用

### 2. 实时性能
- 考虑使用Metal Performance Shaders进行GPU加速
- 实现多线程音频处理流水线
- 优化UI更新频率

### 3. 算法优化
- 实现增量式调式检测（不需要每次重新计算全部历史）
- 使用卡尔曼滤波器平滑检测结果
- 添加置信度加权的历史窗口

## 测试建议

### 1. 单元测试
```swift
// 创建AudioProcessorTests.swift
class AudioProcessorTests: XCTestCase {
    func testFFTAccuracy() {
        // 测试已知频率的正弦波
    }
    
    func testChromaExtraction() {
        // 测试色彩特征提取准确性
    }
}
```

### 2. 性能测试
- 测量平均延迟时间
- 监控CPU和内存使用
- 测试不同音频质量下的表现

### 3. 音乐测试用例
- 准备各种调式的测试音频
- 测试不同乐器组合
- 验证复杂和弦进行的准确性

## 部署步骤

### 1. Xcode项目设置
```bash
# 打开项目
cd MusicAnalyzer
open MusicAnalyzer.xcodeproj

# 设置开发团队和Bundle ID
# 在Project Settings中配置Code Signing
```

### 2. 依赖管理
```swift
// 如果需要添加第三方库，可以使用CocoaPods或Swift Package Manager
// 例如添加音频可视化库：
import Charts  // for audio visualization
```

### 3. 权限配置
确保Info.plist中正确配置了麦克风权限描述。

## 未来扩展计划

### 1. 机器学习增强
- 训练专门的和弦识别模型
- 使用Core ML部署预训练模型
- 实现基于深度学习的调式检测

### 2. 用户体验改进
- 添加音频可视化（频谱图、色彩轮）
- 实现和弦进行的MIDI导出
- 添加练习模式和教学功能

### 3. 高级功能
- 支持复调音乐分析
- 实现实时转调检测
- 添加音乐风格识别

## 常见问题解决

### 1. 音频延迟过高
- 检查音频缓冲区大小设置
- 优化DSP算法复杂度
- 考虑使用较小的FFT窗口

### 2. 和弦检测不准确
- 调整置信度阈值
- 改进色彩特征提取算法
- 添加更多上下文信息

### 3. 界面卡顿
- 减少UI更新频率
- 确保音频处理在后台线程
- 优化界面绘制性能

## 开发工具推荐

1. **Audio分析**: Logic Pro X, Audacity
2. **性能分析**: Instruments (Time Profiler, Allocations)
3. **音乐理论**: MuseScore, Music Theory Helper
4. **调试**: Xcode Audio Unit Host

## 联系与支持

如果在开发过程中遇到问题，建议：
1. 查看Xcode控制台的详细错误信息
2. 使用Instruments分析性能瓶颈
3. 参考Apple的AVFoundation和Accelerate框架文档
4. 测试不同类型的音频输入以验证算法鲁棒性