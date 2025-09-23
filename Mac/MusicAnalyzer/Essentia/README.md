# Essentia iOS 集成

## 集成步骤

1. 将 Essentia 文件添加到 Xcode 项目
2. 配置 Build Settings (参考 GETTING_STARTED.md)
3. 创建桥接头文件 (Swift 项目)
4. 开始使用 Essentia 功能

## 文件说明

- `EssentiaIOSAnalyzer.h/.mm`: 主要分析器类
- `EssentiaSwiftBridge.swift`: Swift 包装器
- `demo_project/`: 示例应用代码
- `documentation/`: 详细文档

## 快速测试

```swift
import Foundation

let analyzer = AudioAnalyzer.shared
if analyzer.isAvailable {
    let result = analyzer.analyzeAudioFile("path/to/audio.wav")
    print(result?.description ?? "分析失败")
}
```

## 注意事项

⚠️ 当前使用的是模拟分析结果
要获得真实结果，需要：
1. 编译真实的 Essentia 静态库
2. 替换模拟实现为真实调用
3. 重新配置项目依赖

参考文档：
- GETTING_STARTED.md (快速开始)
- TECHNICAL_GUIDE.md (技术细节)
'INSTALL_README'

echo ""
echo "✅ 安装完成！"
echo ""
echo "下一步:"
echo "1. 打开 Xcode 项目: $TARGET_PROJECT"
echo "2. 按照 Essentia/README.md 中的说明配置项目"
echo "3. 参考示例代码开始集成"
echo ""
echo "📖 详细文档位置:"
echo "   $TARGET_PROJECT/Essentia/GETTING_STARTED.md"
echo "   $TARGET_PROJECT/Essentia/TECHNICAL_GUIDE.md"
