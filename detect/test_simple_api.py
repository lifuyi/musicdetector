#!/usr/bin/env python3
"""
简化版音乐分析API测试脚本
"""

import requests
import json
import os

def test_simple_api():
    """测试简化版音乐分析API"""
    base_url = "http://localhost:10814"
    
    print("=== 简化版音乐分析API测试 ===\n")
    
    # 1. 检查API状态
    print("1. 检查API状态...")
    response = requests.get(f"{base_url}/health")
    if response.status_code == 200:
        print(f"✓ API运行正常: {response.json()}")
    else:
        print("✗ API未响应")
        return
    
    # 2. 确保测试音频文件存在
    test_audio = "test_chord.wav"
    if not os.path.exists(test_audio):
        print(f"\n2. 创建测试音频文件 {test_audio}...")
        os.system(f"python create_test_audio.py")
    
    # 3. 同步分析音频文件
    print(f"\n2. 分析音频文件 {test_audio}...")
    with open(test_audio, 'rb') as f:
        files = {'file': (test_audio, f, 'audio/wav')}
        data = {'segment_duration': 1.0}
        
        response = requests.post(f"{base_url}/analyze-sync", files=files, data=data)
    
    if response.status_code == 200:
        result = response.json()
        print(f"✓ 分析完成！任务ID: {result['task_id']}")
        
        # 显示结果
        if result['result']:
            data = result['result']
            print(f"\n=== 分析结果 ===")
            print(f"音频信息:")
            print(f"  时长: {data['audio_info']['duration']:.2f} 秒")
            print(f"  采样率: {data['audio_info']['sample_rate']} Hz")
            
            print(f"\n节拍分析:")
            print(f"  速度: {data['beat_analysis']['tempo']:.1f} BPM")
            print(f"  总节拍数: {data['beat_analysis']['total_beats']}")
            
            print(f"\n和弦分析:")
            for i, segment in enumerate(data['segments']):
                print(f"  时间段 {i+1}: {segment['start_time']:.1f}s - {segment['end_time']:.1f}s")
                if segment['chord']:
                    print(f"    和弦: {segment['chord']}")
                if segment['notes']:
                    print(f"    音符: {segment['notes']}")
            
            print(f"\n摘要:")
            print(f"  分析时间段数: {data['summary']['total_segments']}")
            print(f"  检测到的和弦数: {data['summary']['chords_detected']}")
        
        # 保存结果
        result_file = f"simple_analysis_result_{result['task_id']}.json"
        with open(result_file, 'w', encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        print(f"\n✓ 完整结果已保存到: {result_file}")
        
    else:
        print(f"✗ 分析失败: {response.status_code}")
        print(f"  错误信息: {response.text}")
    
    print(f"\n=== 测试完成 ===")

if __name__ == "__main__":
    try:
        test_simple_api()
    except KeyboardInterrupt:
        print("\n用户中断测试")
    except Exception as e:
        print(f"\n测试过程中出现错误: {e}")