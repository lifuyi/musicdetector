#!/usr/bin/env python3
"""
音乐分析API测试脚本
演示如何使用FastAPI音乐分析服务
"""

import requests
import json
import time
import os

def test_api():
    """测试音乐分析API"""
    base_url = "http://localhost:8000"
    
    print("=== 音乐分析API测试 ===\n")
    
    # 1. 检查API状态
    print("1. 检查API状态...")
    response = requests.get(f"{base_url}/health")
    if response.status_code == 200:
        print(f"✓ API运行正常: {response.json()}")
    else:
        print("✗ API未响应")
        return
    
    # 2. 创建测试音频文件（如果不存在）
    test_audio = "test_chord.wav"
    if not os.path.exists(test_audio):
        print(f"\n2. 创建测试音频文件 {test_audio}...")
        os.system(f"python create_test_audio.py")
    
    if os.path.exists(test_audio):
        print(f"✓ 测试音频文件已准备: {test_audio}")
    else:
        print("✗ 无法创建测试音频文件")
        return
    
    # 3. 上传音频文件进行分析
    print(f"\n3. 上传音频文件进行分析...")
    with open(test_audio, 'rb') as f:
        files = {'file': (test_audio, f, 'audio/wav')}
        data = {
            'segment_duration': 1.0,
            'analyze_beats': True,
            'analyze_chords': True,
            'analyze_spectral': True
        }
        
        response = requests.post(f"{base_url}/upload-audio", files=files, data=data)
    
    if response.status_code == 200:
        result = response.json()
        task_id = result['task_id']
        print(f"✓ 文件上传成功，任务ID: {task_id}")
        print(f"  状态: {result['status']}")
        print(f"  消息: {result['message']}")
    else:
        print(f"✗ 文件上传失败: {response.status_code}")
        print(f"  错误信息: {response.text}")
        return
    
    # 4. 轮询任务状态
    print(f"\n4. 等待分析完成...")
    max_wait = 60  # 最多等待60秒
    wait_time = 0
    
    while wait_time < max_wait:
        response = requests.get(f"{base_url}/analysis-status/{task_id}")
        if response.status_code == 200:
            status = response.json()
            print(f"  进度: {status['progress']}% - {status['status']}")
            
            if status['status'] == 'completed':
                print("✓ 分析完成！")
                break
            elif status['status'] == 'failed':
                print(f"✗ 分析失败: {status.get('error', '未知错误')}")
                return
        else:
            print(f"✗ 无法获取任务状态: {response.status_code}")
            return
        
        time.sleep(2)
        wait_time += 2
    
    # 5. 获取分析结果
    print(f"\n5. 获取分析结果...")
    response = requests.get(f"{base_url}/analysis-result/{task_id}")
    
    if response.status_code == 200:
        result = response.json()
        
        print("=== 分析结果 ===")
        print(f"音频信息:")
        print(f"  时长: {result['audio_info']['duration']:.2f} 秒")
        print(f"  采样率: {result['audio_info']['sample_rate']} Hz")
        print(f"  文件名: {result['audio_info']['filename']}")
        
        print(f"\n节拍分析:")
        print(f"  速度: {result['beat_analysis']['tempo']:.1f} BPM")
        print(f"  总节拍数: {result['beat_analysis']['total_beats']}")
        print(f"  小节数: {result['beat_analysis']['total_measures']}")
        print(f"  平均节拍间隔: {result['beat_analysis']['average_beat_interval']:.3f} 秒")
        
        print(f"\n分析摘要:")
        print(f"  总时间段: {result['summary']['total_segments']}")
        print(f"  检测到的和弦: {result['summary']['chords_detected']}")
        
        # 显示前几个时间段的详细分析
        if result['segments']:
            print(f"\n前3个时间段的详细分析:")
            for i, segment in enumerate(result['segments'][:3]):
                print(f"\n  时间段 {i+1}: {segment['start_time']:.1f}s - {segment['end_time']:.1f}s")
                print(f"    节拍数: {len(segment['beats'])}")
                print(f"    和弦: {segment.get('chord', '无')}")
                print(f"    音符: {segment.get('notes', [])}")
                print(f"    频谱质心: {segment['spectral_features']['spectral_centroid']:.1f} Hz")
                print(f"    节奏复杂度: {segment['rhythm_pattern']['rhythm_complexity']:.3f}")
                print(f"    估计小节数: {segment['estimated_measures']}")
        
        # 保存完整结果到文件
        result_file = f"analysis_result_{task_id}.json"
        with open(result_file, 'w', encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        print(f"\n✓ 完整结果已保存到: {result_file}")
        
    else:
        print(f"✗ 无法获取分析结果: {response.status_code}")
    
    # 6. 获取活跃任务列表
    print(f"\n6. 获取活跃任务列表...")
    response = requests.get(f"{base_url}/active-tasks")
    if response.status_code == 200:
        tasks_info = response.json()
        print(f"当前活跃任务数: {tasks_info['total']}")
        for task in tasks_info['tasks']:
            print(f"  - {task['task_id']}: {task['status']} ({task['progress']}%)")
    
    print(f"\n=== 测试完成 ===")

def cleanup_tasks():
    """清理所有任务"""
    base_url = "http://localhost:8000"
    response = requests.get(f"{base_url}/active-tasks")
    
    if response.status_code == 200:
        tasks_info = response.json()
        for task in tasks_info['tasks']:
            task_id = task['task_id']
            delete_response = requests.delete(f"{base_url}/analysis-task/{task_id}")
            if delete_response.status_code == 200:
                print(f"已删除任务: {task_id}")

if __name__ == "__main__":
    try:
        test_api()
    except KeyboardInterrupt:
        print("\n用户中断测试")
    except Exception as e:
        print(f"\n测试过程中出现错误: {e}")
    finally:
        # 可选：清理测试任务
        # cleanup_tasks()
        pass