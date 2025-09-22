#!/usr/bin/env python3
"""
Test script to verify the real-time analysis improvements
Simulates the Mac app's analysis process
"""

import numpy as np
import time
import json
from typing import Dict, List, Optional

class MockAudioFeatures:
    """模拟音频特征数据"""
    def __init__(self, chroma: List[float], magnitude: List[float], timestamp: float):
        self.chroma = chroma
        self.magnitude = magnitude
        self.timestamp = timestamp

class MockMusicAnalysisEngine:
    """模拟Mac app的音乐分析引擎"""
    
    def __init__(self):
        self.feature_history = []
        self.onset_strengths = []
        self.bpm_estimate = 120.0  # 默认BPM
        self.has_valid_bpm = True
        self.current_key = None
        self.chord_history = []
        
        # 优化的参数
        self.key_confidence_threshold = 0.05  # 从0.001提高到0.05
        self.beat_history_size = 30  # 从50减少到30
        self.min_onset_count = 3  # 从10降到3
        
        # 音符名称
        self.note_names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        
        # 调式特征
        self.key_profiles = {
            "major": [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88],
            "minor": [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
        }
    
    def generate_mock_features(self, bpm: float = 120.0, key: str = "C", mode: str = "major") -> MockAudioFeatures:
        """生成模拟的音频特征数据"""
        timestamp = time.time()
        
        # 生成色度特征（基于调式）
        chroma = self.key_profiles[mode].copy()
        
        # 添加一些随机变化
        chroma = [c + np.random.normal(0, 0.1) for c in chroma]
        chroma = [max(0, c) for c in chroma]  # 确保非负
        
        # 归一化
        chroma_sum = sum(chroma)
        if chroma_sum > 0:
            chroma = [c / chroma_sum for c in chroma]
        
        # 生成幅度特征（模拟节拍）
        magnitude = [np.random.random() * 0.5 + 0.5 for _ in range(128)]
        
        # 根据BPM添加节拍模式
        beat_phase = (timestamp * bpm / 60.0) % 1.0
        if beat_phase < 0.1:  # 重拍
            magnitude = [m * 1.5 for m in magnitude]
        
        return MockAudioFeatures(chroma, magnitude, timestamp)
    
    def analyze_beat(self, features: MockAudioFeatures) -> Dict:
        """分析节拍 - 改进版本"""
        current_time = features.timestamp
        
        # 计算onset强度
        onset_strength = self.calculate_onset_strength(features)
        self.onset_strengths.append(onset_strength)
        
        # 保持合理的历史长度
        if len(self.onset_strengths) > 50:
            self.onset_strengths.pop(0)
        
        print(f"📊 Onset detection: {len(self.onset_strengths)}/3 samples, current strength: {onset_strength:.3f}")
        
        # 立即开始分析，即使数据较少
        if len(self.onset_strengths) < 3:
            print(f"⏳ Initializing beat detection (current: {len(self.onset_strengths)}/3)...")
            return {
                "bpm": self.bpm_estimate,
                "confidence": 0.1,
                "beat_position": 0.0,
                "measure_position": 1
            }
        
        # 简化的节拍跟踪
        beat_info = self.track_beats(onset_strengths=self.onset_strengths, current_time=current_time)
        
        print(f"🎯 Beat tracking result: BPM={beat_info['bpm']:.1f}, Confidence={beat_info['confidence']:.2f}")
        
        # 更快更新BPM估计
        if beat_info["bpm"] > 0 and beat_info["confidence"] > 0.01:
            self.bpm_estimate = beat_info["bpm"]
            self.has_valid_bpm = True
            print(f"✅ BPM updated: {self.bpm_estimate}")
        elif beat_info["bpm"] > 0 and len(self.onset_strengths) > 10:
            # 数据足够多时，即使置信度稍低也接受
            self.bpm_estimate = beat_info["bpm"]
            self.has_valid_bpm = True
            print(f"⚠️ BPM accepted with sufficient data: {self.bpm_estimate}")
        
        return beat_info
    
    def analyze_key(self) -> Optional[Dict]:
        """分析调式 - 改进版本"""
        if len(self.feature_history) < 1:
            print(f"🎵 Key detection: waiting for feature data (current: {len(self.feature_history)})")
            return None
        
        print(f"🎵 Starting key detection with {len(self.feature_history)} feature samples")
        
        # 使用更快的分析策略
        recent_feature_count = min(20, len(self.feature_history))
        recent_features = self.feature_history[-recent_feature_count:]
        
        # 计算加权色度特征
        weighted_chroma = [0.0] * 12
        total_weight = 0.0
        
        for index, features in enumerate(recent_features):
            weight = (index + 1) / len(recent_features)  # 越新的权重越大
            for i in range(12):
                weighted_chroma[i] += features.chroma[i] * weight
            total_weight += weight
        
        # 归一化
        if total_weight > 0:
            weighted_chroma = [c / total_weight for c in weighted_chroma]
        
        # 快速调式检测
        key_scores = []
        for root in range(12):
            for mode in ["major", "minor"]:
                score = self.calculate_fast_key_score(weighted_chroma, root, mode)
                key_scores.append({
                    "root": root,
                    "mode": mode,
                    "score": score
                })
        
        # 排序获得最佳匹配
        key_scores.sort(key=lambda x: x["score"], reverse=True)
        
        best_score = key_scores[0]["score"]
        print(f"🎵 Key detection: best score: {best_score:.4f}")
        
        if best_score >= self.key_confidence_threshold:
            best_key = key_scores[0]
            key_name = self.note_names[best_key["root"]]
            mode_name = "大调" if best_key["mode"] == "major" else "小调"
            
            print(f"🎵 Key detection successful: {key_name} {mode_name} (confidence: {best_score})")
            
            return {
                "root": best_key["root"],
                "mode": best_key["mode"],
                "confidence": best_score,
                "name": f"{key_name} {mode_name}"
            }
        else:
            # 数据足够多时，即使置信度稍低也返回结果
            if len(self.feature_history) > 15 and best_score > self.key_confidence_threshold * 0.5:
                best_key = key_scores[0]
                key_name = self.note_names[best_key["root"]]
                mode_name = "大调" if best_key["mode"] == "major" else "小调"
                
                print(f"🎵 Key detection: accepting lower confidence with sufficient data")
                return {
                    "root": best_key["root"],
                    "mode": best_key["mode"],
                    "confidence": best_score * 0.8,
                    "name": f"{key_name} {mode_name}"
                }
            
            print(f"🎵 Key detection failed: score {best_score:.4f} < threshold {self.key_confidence_threshold}")
            return None
    
    def calculate_onset_strength(self, features: MockAudioFeatures) -> float:
        """计算起始强度"""
        if not self.feature_history:
            return 0.0
        
        previous_features = self.feature_history[-1]
        
        # 计算谱通量
        spectral_flux = 0.0
        for i in range(min(len(features.magnitude), len(previous_features.magnitude))):
            diff = features.magnitude[i] - previous_features.magnitude[i]
            if diff > 0:
                spectral_flux += diff
        
        return spectral_flux
    
    def calculate_fast_key_score(self, chroma: List[float], root: int, mode: str) -> float:
        """快速调式评分算法"""
        profile = self.key_profiles[mode]
        
        # 简化的相关性计算
        correlation = 0.0
        profile_sum = sum(profile)
        
        for i in range(12):
            rotated_index = (i + root) % 12
            correlation += chroma[i] * profile[rotated_index]
        
        # 归一化
        normalized_correlation = correlation / profile_sum if profile_sum > 0 else 0
        
        # 主音强度奖励
        tonic_bonus = chroma[root] * 0.2
        
        return normalized_correlation + tonic_bonus
    
    def track_beats(self, onset_strengths: List[float], current_time: float) -> Dict:
        """简化的节拍跟踪"""
        if len(onset_strengths) < 3:
            return {
                "bpm": self.bpm_estimate,
                "confidence": 0.1,
                "beat_position": 0.0,
                "measure_position": 1
            }
        
        # 简单的峰值检测
        peaks = []
        for i in range(1, len(onset_strengths) - 1):
            if (onset_strengths[i] > onset_strengths[i-1] and 
                onset_strengths[i] > onset_strengths[i+1] and
                onset_strengths[i] > 0.1):
                peaks.append(i)
        
        if len(peaks) > 1:
            # 计算平均间隔
            intervals = []
            for i in range(1, len(peaks)):
                intervals.append(peaks[i] - peaks[i-1])
            
            avg_interval = sum(intervals) / len(intervals)
            # 转换为BPM (假设采样率为 ~43Hz)
            estimated_bpm = 60.0 * 43.0 / avg_interval
            
            # 限制在合理范围内
            if 60 <= estimated_bpm <= 200:
                confidence = min(1.0, len(peaks) / 10.0)
                return {
                    "bpm": estimated_bpm,
                    "confidence": confidence,
                    "beat_position": (current_time % 1.0),
                    "measure_position": int(current_time % 4) + 1
                }
        
        return {
            "bpm": self.bpm_estimate,
            "confidence": 0.1,
            "beat_position": (current_time % 1.0),
            "measure_position": int(current_time % 4) + 1
        }
    
    def run_simulation(self, duration_seconds: int = 10, target_bpm: float = 120.0, target_key: str = "C"):
        """运行模拟测试"""
        print(f"🎵 开始实时分析模拟测试")
        print(f"🎯 目标: BPM={target_bpm}, Key={target_key}")
        print(f"⏱️  持续时间: {duration_seconds}秒")
        print("=" * 50)
        
        start_time = time.time()
        iteration = 0
        
        while time.time() - start_time < duration_seconds:
            iteration += 1
            current_time = time.time() - start_time
            
            # 生成模拟音频特征
            features = self.generate_mock_features(bpm=target_bpm, key=target_key)
            self.feature_history.append(features)
            
            # 保持历史记录在合理范围内
            if len(self.feature_history) > 100:
                self.feature_history.pop(0)
            
            # 分析节拍
            beat_result = self.analyze_beat(features)
            
            # 分析调式
            key_result = self.analyze_key()
            
            # 显示结果
            print(f"\n⏰ 时间: {current_time:.1f}s, 迭代: {iteration}")
            print(f"🥁 节拍: BPM={beat_result['bpm']:.1f}, 置信度={beat_result['confidence']:.2f}")
            
            if key_result:
                print(f"🎼 调式: {key_result['name']}, 置信度={key_result['confidence']:.3f}")
            else:
                print(f"🎼 调式: 检测中... (历史数据: {len(self.feature_history)})")
            
            # 模拟音频处理间隔 (~100ms)
            time.sleep(0.1)
        
        print("\n" + "=" * 50)
        print(f"✅ 模拟测试完成")
        print(f"📊 最终BPM: {self.bpm_estimate:.1f}")
        if self.current_key:
            key_result = self.analyze_key()
            if key_result:
                print(f"📊 最终调式: {key_result['name']}")
        print(f"📊 总迭代次数: {iteration}")

if __name__ == "__main__":
    # 运行测试
    engine = MockMusicAnalysisEngine()
    
    # 测试1: 标准速度和调式
    print("🧪 测试1: 标准参数 (BPM=120, Key=C)")
    engine.run_simulation(duration_seconds=5, target_bpm=120.0, target_key="C")
    
    print("\n" + "="*60 + "\n")
    
    # 测试2: 快速度和不同调式
    print("🧪 测试2: 快速度和D小调 (BPM=140, Key=D)")
    engine = MockMusicAnalysisEngine()  # 重置引擎
    engine.run_simulation(duration_seconds=5, target_bpm=140.0, target_key="D")
    
    print("\n" + "="*60 + "\n")
    
    # 测试3: 慢速度和F大调
    print("🧪 测试3: 慢速度和F大调 (BPM=80, Key=F)")
    engine = MockMusicAnalysisEngine()  # 重置引擎
    engine.run_simulation(duration_seconds=5, target_bpm=80.0, target_key="F")