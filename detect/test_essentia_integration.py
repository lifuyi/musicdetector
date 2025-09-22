#!/usr/bin/env python3
"""
Essentia 集成测试脚本
用于验证 Essentia 安装和功能
"""

import os
import sys
import time
from pathlib import Path

def test_essentia_import():
    """测试 Essentia 导入"""
    print("🔍 测试 Essentia 导入...")
    try:
        import essentia
        import essentia.standard as es
        print("✅ Essentia 导入成功")
        print(f"📦 Essentia 版本: {essentia.__version__}")
        return True
    except ImportError as e:
        print(f"❌ Essentia 导入失败: {e}")
        print("💡 安装建议:")
        print("   pip install essentia-tensorflow")
        print("   或")
        print("   conda install -c mtg essentia")
        return False

def test_essentia_analyzer():
    """测试 EssentiaAnalyzer 类"""
    print("\n🔍 测试 EssentiaAnalyzer...")
    try:
        from essentia_analyzer import EssentiaAnalyzer
        analyzer = EssentiaAnalyzer()
        print("✅ EssentiaAnalyzer 初始化成功")
        return analyzer
    except Exception as e:
        print(f"❌ EssentiaAnalyzer 初始化失败: {e}")
        return None

def test_with_sample_file(analyzer):
    """使用测试文件进行分析"""
    print("\n🔍 测试音频文件分析...")
    
    # 查找测试文件
    test_files = ["test_chord.wav", "sample_music.mp3", "test.wav"]
    test_file = None
    
    for filename in test_files:
        if os.path.exists(filename):
            test_file = filename
            break
    
    if not test_file:
        print("⚠️ 未找到测试音频文件")
        print("💡 可以运行以下命令创建测试文件:")
        print("   python create_test_audio.py")
        return False
    
    print(f"📁 使用测试文件: {test_file}")
    
    try:
        start_time = time.time()
        result = analyzer.comprehensive_analysis(test_file)
        analysis_time = time.time() - start_time
        
        print(f"⏱️ 分析耗时: {analysis_time:.2f} 秒")
        print("\n📊 分析结果:")
        print(f"   BPM: {result['rhythm_analysis']['bpm']:.1f}")
        print(f"   BPM 置信度: {result['rhythm_analysis'].get('confidence', 0):.3f}")
        print(f"   调性: {result['key_analysis']['key']} {result['key_analysis']['scale']}")
        print(f"   调性强度: {result['key_analysis']['strength']:.3f}")
        print(f"   整体质量: {result['overall_quality']:.3f}")
        print(f"   使用建议: {result['recommended_use']}")
        
        # 验证结果合理性
        bpm = result['rhythm_analysis']['bpm']
        if 60 <= bpm <= 200:
            print("✅ BPM 值在合理范围内")
        else:
            print(f"⚠️ BPM 值异常: {bpm}")
        
        key = result['key_analysis']['key']
        valid_keys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
        if key in valid_keys:
            print("✅ 调性检测正常")
        else:
            print(f"⚠️ 调性检测异常: {key}")
        
        return True
        
    except Exception as e:
        print(f"❌ 音频分析失败: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_api_endpoints():
    """测试 API 端点"""
    print("\n🔍 测试 API 集成...")
    
    try:
        import requests
        base_url = "http://localhost:10814"
        
        # 测试状态端点
        print("📡 测试 /essentia-status...")
        response = requests.get(f"{base_url}/essentia-status", timeout=5)
        if response.status_code == 200:
            status = response.json()
            print("✅ API 服务可用")
            print(f"   Essentia 状态: {'可用' if status['essentia_available'] else '不可用'}")
            print(f"   支持格式: {', '.join(status['supported_formats'])}")
        else:
            print(f"❌ API 状态检查失败: {response.status_code}")
            
    except requests.exceptions.ConnectionError:
        print("⚠️ API 服务未启动")
        print("💡 启动建议: python music_api.py")
    except ImportError:
        print("⚠️ requests 库未安装")
        print("💡 安装建议: pip install requests")
    except Exception as e:
        print(f"❌ API 测试失败: {e}")

def run_benchmark():
    """运行性能基准测试"""
    print("\n🔍 运行性能基准测试...")
    
    try:
        from essentia_analyzer import EssentiaAnalyzer
        analyzer = EssentiaAnalyzer()
        
        # 查找测试文件
        test_file = None
        for filename in ["test_chord.wav", "sample_music.mp3"]:
            if os.path.exists(filename):
                test_file = filename
                break
        
        if not test_file:
            print("⚠️ 跳过基准测试：无测试文件")
            return
        
        print(f"📁 基准测试文件: {test_file}")
        
        # 多次运行测试
        times = []
        num_runs = 3
        
        for i in range(num_runs):
            start_time = time.time()
            result = analyzer.comprehensive_analysis(test_file)
            end_time = time.time()
            times.append(end_time - start_time)
            print(f"   运行 {i+1}: {times[-1]:.2f}s")
        
        avg_time = sum(times) / len(times)
        min_time = min(times)
        max_time = max(times)
        
        print(f"\n📈 性能统计 ({num_runs} 次运行):")
        print(f"   平均耗时: {avg_time:.2f}s")
        print(f"   最快耗时: {min_time:.2f}s")
        print(f"   最慢耗时: {max_time:.2f}s")
        
        # 性能评估
        if avg_time < 2.0:
            print("✅ 性能优秀")
        elif avg_time < 5.0:
            print("👍 性能良好")
        else:
            print("⚠️ 性能需要优化")
            
    except Exception as e:
        print(f"❌ 基准测试失败: {e}")

def main():
    """主测试函数"""
    print("🎵 Essentia 音频处理核心集成测试")
    print("=" * 50)
    
    # 1. 测试 Essentia 导入
    if not test_essentia_import():
        print("\n❌ 测试中止：Essentia 未正确安装")
        sys.exit(1)
    
    # 2. 测试分析器初始化
    analyzer = test_essentia_analyzer()
    if not analyzer:
        print("\n❌ 测试中止：EssentiaAnalyzer 初始化失败")
        sys.exit(1)
    
    # 3. 测试音频文件分析
    if not test_with_sample_file(analyzer):
        print("\n⚠️ 音频分析测试失败")
    
    # 4. 测试 API 集成
    test_api_endpoints()
    
    # 5. 运行性能基准测试
    run_benchmark()
    
    print("\n🎉 测试完成！")
    print("\n📝 下一步:")
    print("1. 启动 API 服务: python music_api.py")
    print("2. 测试 iOS/Mac 客户端集成")
    print("3. 使用真实音乐文件进行验证")

if __name__ == "__main__":
    main()