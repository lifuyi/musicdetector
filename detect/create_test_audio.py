#!/usr/bin/env python3
"""
创建测试音频文件
用于测试音乐分析API
"""

import numpy as np
import wave
import struct


def create_test_chord_wav(filename="test_chord.wav", duration=4.0, sample_rate=44100):
    """创建一个包含C大调和弦的测试音频文件"""
    
    # C大调和弦的频率 (C4, E4, G4)
    frequencies = [261.63, 329.63, 392.00]  # C4, E4, G4
    
    # 生成时间轴
    t = np.linspace(0, duration, int(sample_rate * duration), False)
    
    # 生成复合波形
    audio = np.zeros_like(t)
    for freq in frequencies:
        audio += 0.3 * np.sin(2 * np.pi * freq * t)
    
    # 添加一些节拍变化 (4/4拍，120 BPM)
    bpm = 120
    beat_duration = 60.0 / bpm
    beats_per_measure = 4
    
    # 创建节拍包络
    envelope = np.ones_like(t)
    for i in range(int(duration / beat_duration)):
        beat_start = i * beat_duration
        beat_end = beat_start + 0.05  # 50ms的节拍强调
        
        start_idx = int(beat_start * sample_rate)
        end_idx = int(min(beat_end, duration) * sample_rate)
        
        if start_idx < len(envelope):
            end_idx = min(end_idx, len(envelope))
            envelope[start_idx:end_idx] *= 1.5
    
    # 应用节拍包络
    audio *= envelope
    
    # 添加一些衰减效果
    fade_out = np.linspace(1, 0.7, len(t))
    audio *= fade_out
    
    # 归一化到16位整数范围
    audio = audio / np.max(np.abs(audio)) * 0.8 * (2**15 - 1)
    audio = audio.astype(np.int16)
    
    # 写入WAV文件
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)  # 单声道
        wav_file.setsampwidth(2)  # 16位
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(audio.tobytes())
    
    print(f"测试音频文件已创建: {filename}")
    print(f"时长: {duration} 秒")
    print(f"采样率: {sample_rate} Hz")
    print(f"包含和弦: C大调 (C4-E4-G4)")
    print(f"节拍: 120 BPM, 4/4拍")


if __name__ == "__main__":
    create_test_chord_wav()
    print("\n可以使用以下命令测试音乐分析API:")
    print("python test_api.py        # 测试完整版API")
    print("python test_simple_api.py  # 测试简化版API")