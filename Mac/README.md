# Music Key & Chord Detection macOS App

## 项目概述
实时音乐调式和和弦检测macOS桌面应用，支持：
- 麦克风、文件和URL音频输入
- 实时节拍和小节检测
- 调式识别（高置信度显示）
- 和弦级数分析
- 延迟 < 1秒

## 技术栈
- Swift + AppKit/Cocoa
- AVFoundation (音频处理)
- Accelerate (DSP计算)
- Core ML (机器学习推理)
- Charts (数据可视化)

## 架构设计
```
AudioInputManager → AudioProcessor → FeatureExtractor → AnalysisEngine → UIDisplayManager
```

## 开发计划
1. 音频输入和实时处理管道
2. 节拍检测算法
3. 小节分割逻辑
4. 和弦识别模型
5. 调式检测算法
6. UI界面和实时显示