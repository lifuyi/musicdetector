"""
Essentia 音频分析器
提供高精度的 BPM 检测和调性分析功能
"""

import os
import time
import numpy as np
from typing import Dict, List, Tuple, Optional

try:
    import essentia
    import essentia.standard as es
    ESSENTIA_AVAILABLE = True
except ImportError:
    ESSENTIA_AVAILABLE = False
    print("警告: Essentia 未安装，将使用 librosa 作为备选方案")

try:
    import librosa
    LIBROSA_AVAILABLE = True
except ImportError:
    LIBROSA_AVAILABLE = False
    print("警告: librosa 未安装")


class EssentiaAnalyzer:
    """基于 Essentia 的高精度音频分析器"""
    
    def __init__(self):
        """初始化 Essentia 分析器"""
        if not ESSENTIA_AVAILABLE:
            raise ImportError("Essentia 未安装。请运行: pip install essentia-tensorflow")
        
        # 初始化 Essentia 算法
        self._init_rhythm_algorithms()
        self._init_key_algorithms()
        self._init_feature_algorithms()
        
    def _init_rhythm_algorithms(self):
        """初始化节奏分析算法"""
        # 主要的节奏提取器 (2013版本，更准确)
        self.rhythm_extractor = es.RhythmExtractor2013(method="multifeature")
        
        # 多特征节拍跟踪器
        self.beat_tracker = es.BeatTrackerMultiFeature()
        
        # Degara 节拍跟踪器 (适合复杂音乐)
        self.beat_tracker_degara = es.BeatTrackerDegara()
        
        # 节拍强度检测
        self.beats_loudness = es.BeatsLoudness()
        
        # Onset 检测器
        self.onset_rate = es.OnsetRate()
        
    def _init_key_algorithms(self):
        """初始化调性分析算法"""
        # EDMA 调性提取器 (更适合现代音乐)
        self.key_extractor = es.KeyExtractor(profileType='edma')
        
        # 传统 Krumhansl-Schmuckler 算法
        self.key_extractor_traditional = es.KeyExtractor(profileType='bgate')
        
        # 调性强度分析
        self.key_strength = es.KeyExtractor(profileType='temperley')
        
    def _init_feature_algorithms(self):
        """初始化特征提取算法"""
        # 色彩特征
        self.chroma = es.ChromaCrossSimilarity()
        self.hpcp = es.HPCP()
        
        # 频谱特征
        self.spectral_centroid = es.SpectralCentroidTime()
        self.spectral_rolloff = es.RollOff()
        
        # 音频加载器
        self.mono_loader = es.MonoLoader()
        
    def analyze_bpm_and_beats(self, audio_file_path: str) -> Dict:
        """
        使用 Essentia 分析 BPM 和节拍
        
        Args:
            audio_file_path: 音频文件路径
            
        Returns:
            包含 BPM、节拍位置、置信度等信息的字典
        """
        try:
            # 加载音频
            self.mono_loader.configure(filename=audio_file_path)
            audio = self.mono_loader()
            
            if len(audio) == 0:
                raise ValueError(f"无法加载音频文件: {audio_file_path}")
            
            # 使用 RhythmExtractor2013 进行主分析
            bpm, beats, beats_confidence, _, beats_intervals = self.rhythm_extractor(audio)
            
            # 使用多特征节拍跟踪器获得更精确的节拍位置
            beat_positions = self.beat_tracker(audio)
            
            # 使用 Degara 算法作为备选验证
            try:
                degara_beats = self.beat_tracker_degara(audio)
            except Exception as e:
                print(f"Degara 节拍检测失败: {e}")
                degara_beats = []
            
            # 计算节拍强度
            try:
                loudness_values = self.beats_loudness(audio, beat_positions)
            except Exception:
                loudness_values = []
            
            # 计算 Onset 率
            try:
                onset_rate_value = self.onset_rate(audio)
            except Exception:
                onset_rate_value = 0.0
            
            # 验证和调整 BPM
            validated_bpm = self._validate_bpm(float(bpm), beats, audio)
            
            return {
                'bpm': float(validated_bpm),
                'bpm_raw': float(bpm),
                'beats': beats.tolist() if hasattr(beats, 'tolist') and len(beats) > 0 else [],
                'confidence': float(beats_confidence),
                'beat_positions': beat_positions.tolist() if hasattr(beat_positions, 'tolist') and len(beat_positions) > 0 else [],
                'beat_intervals': beats_intervals.tolist() if hasattr(beats_intervals, 'tolist') and len(beats_intervals) > 0 else [],
                'degara_beats': degara_beats.tolist() if hasattr(degara_beats, 'tolist') and len(degara_beats) > 0 else [],
                'beat_loudness': loudness_values.tolist() if hasattr(loudness_values, 'tolist') and len(loudness_values) > 0 else [],
                'onset_rate': float(onset_rate_value),
                'audio_duration': len(audio) / 44100.0,  # 假设采样率为 44.1kHz
                'analysis_engine': 'essentia',
                'quality_score': self._calculate_rhythm_quality_score(beats_confidence, onset_rate_value)
            }
            
        except Exception as e:
            print(f"Essentia 节拍分析失败: {e}")
            # 备选方案：使用 librosa
            return self._fallback_bpm_analysis(audio_file_path)
    
    def analyze_key(self, audio_file_path: str) -> Dict:
        """
        使用 Essentia 分析调性
        
        Args:
            audio_file_path: 音频文件路径
            
        Returns:
            包含调性、音阶、强度等信息的字典
        """
        try:
            # 加载音频
            self.mono_loader.configure(filename=audio_file_path)
            audio = self.mono_loader()
            
            if len(audio) == 0:
                raise ValueError(f"无法加载音频文件: {audio_file_path}")
            
            # 使用 EDMA 算法 (推荐用于现代音乐)
            key_edma, scale_edma, strength_edma = self.key_extractor(audio)
            
            # 使用传统算法作为对比
            key_traditional, scale_traditional, strength_traditional = self.key_extractor_traditional(audio)
            
            # 使用 Temperley 算法获得强度评估
            key_temperley, scale_temperley, strength_temperley = self.key_strength(audio)
            
            # 选择最可信的结果
            best_result = self._select_best_key_result([
                (key_edma, scale_edma, strength_edma, 'edma'),
                (key_traditional, scale_traditional, strength_traditional, 'traditional'),
                (key_temperley, scale_temperley, strength_temperley, 'temperley')
            ])
            
            # 计算调性稳定性
            stability_score = self._calculate_key_stability(audio)
            
            return {
                'key': best_result[0],
                'scale': best_result[1],
                'strength': float(best_result[2]),
                'algorithm': best_result[3],
                'alternatives': {
                    'edma': {'key': key_edma, 'scale': scale_edma, 'strength': float(strength_edma)},
                    'traditional': {'key': key_traditional, 'scale': scale_traditional, 'strength': float(strength_traditional)},
                    'temperley': {'key': key_temperley, 'scale': scale_temperley, 'strength': float(strength_temperley)}
                },
                'stability_score': float(stability_score),
                'confidence_level': self._get_confidence_level(best_result[2]),
                'analysis_engine': 'essentia'
            }
            
        except Exception as e:
            print(f"Essentia 调性分析失败: {e}")
            # 备选方案：使用基础算法
            return self._fallback_key_analysis(audio_file_path)
    
    def comprehensive_analysis(self, audio_file_path: str) -> Dict:
        """
        综合分析音频文件
        
        Args:
            audio_file_path: 音频文件路径
            
        Returns:
            包含节奏和调性分析的完整结果
        """
        if not os.path.exists(audio_file_path):
            raise FileNotFoundError(f"音频文件不存在: {audio_file_path}")
        
        print(f"开始 Essentia 综合分析: {audio_file_path}")
        
        # 节奏分析
        rhythm_data = self.analyze_bpm_and_beats(audio_file_path)
        
        # 调性分析
        key_data = self.analyze_key(audio_file_path)
        
        # 计算整体分析质量
        overall_quality = self._calculate_overall_quality(rhythm_data, key_data)
        
        return {
            'rhythm_analysis': rhythm_data,
            'key_analysis': key_data,
            'analysis_engine': 'essentia',
            'file_path': audio_file_path,
            'overall_quality': overall_quality,
            'analysis_timestamp': time.time(),
            'recommended_use': self._get_usage_recommendation(overall_quality)
        }
    
    def _validate_bpm(self, bpm: float, beats: np.ndarray, audio: np.ndarray) -> float:
        """验证和调整 BPM 值"""
        # 检查 BPM 是否在合理范围内
        if bpm < 60 or bpm > 200:
            # 尝试倍频或分频
            if bpm < 60:
                adjusted_bpm = bpm * 2
            else:
                adjusted_bpm = bpm / 2
            
            # 确保调整后的 BPM 在合理范围内
            if 60 <= adjusted_bpm <= 200:
                return adjusted_bpm
        
        return max(60, min(200, bpm))  # 限制在 60-200 BPM 范围内
    
    def _calculate_rhythm_quality_score(self, confidence: float, onset_rate: float) -> float:
        """计算节奏分析质量分数"""
        # 基于置信度和 onset 率计算综合质量分数
        confidence_score = min(confidence * 100, 100)  # 转换为百分比
        onset_score = min(onset_rate * 10, 100)  # onset 率通常较小，放大处理
        
        return (confidence_score * 0.7 + onset_score * 0.3) / 100
    
    def _select_best_key_result(self, results: List[Tuple]) -> Tuple:
        """选择最佳调性检测结果"""
        # 根据强度值选择最可信的结果
        best_result = max(results, key=lambda x: x[2])
        
        # 如果最佳结果的强度太低，尝试选择次佳但更稳定的结果
        if best_result[2] < 0.3:
            # 按强度排序，选择前两个进行比较
            sorted_results = sorted(results, key=lambda x: x[2], reverse=True)
            if len(sorted_results) >= 2:
                first, second = sorted_results[0], sorted_results[1]
                if second[2] > 0.2 and (first[2] - second[2]) < 0.1:
                    # 如果差距很小，选择更传统的算法结果
                    if second[3] in ['traditional', 'temperley']:
                        return second
        
        return best_result
    
    def _calculate_key_stability(self, audio: np.ndarray) -> float:
        """计算调性稳定性"""
        # 将音频分段分析，检查调性一致性
        segment_length = len(audio) // 4  # 分成4段
        if segment_length < 44100:  # 如果段太短，返回默认值
            return 0.5
        
        keys = []
        for i in range(4):
            start = i * segment_length
            end = start + segment_length
            segment = audio[start:end]
            
            try:
                key, _, strength = self.key_extractor(segment)
                if strength > 0.1:  # 只考虑有一定置信度的结果
                    keys.append(key)
            except:
                continue
        
        if len(keys) < 2:
            return 0.5
        
        # 计算一致性
        most_common_key = max(set(keys), key=keys.count)
        consistency = keys.count(most_common_key) / len(keys)
        
        return consistency
    
    def _get_confidence_level(self, strength: float) -> str:
        """获取置信度等级描述"""
        if strength >= 0.7:
            return "高"
        elif strength >= 0.4:
            return "中"
        elif strength >= 0.2:
            return "低"
        else:
            return "极低"
    
    def _calculate_overall_quality(self, rhythm_data: Dict, key_data: Dict) -> float:
        """计算整体分析质量"""
        rhythm_quality = rhythm_data.get('quality_score', 0)
        key_quality = key_data.get('strength', 0)
        
        return (rhythm_quality + key_quality) / 2
    
    def _get_usage_recommendation(self, quality: float) -> str:
        """根据质量分数给出使用建议"""
        if quality >= 0.7:
            return "结果可靠，建议直接使用"
        elif quality >= 0.4:
            return "结果较好，建议结合其他算法验证"
        elif quality >= 0.2:
            return "结果一般，建议人工确认"
        else:
            return "结果不可靠，建议重新分析或使用其他方法"
    
    def _fallback_bpm_analysis(self, audio_file_path: str) -> Dict:
        """备选 BPM 分析（使用 librosa）"""
        if not LIBROSA_AVAILABLE:
            return {
                'bpm': 120.0,  # 默认 BPM
                'error': 'librosa not available',
                'analysis_engine': 'fallback_unavailable'
            }
        try:
            y, sr = librosa.load(audio_file_path)
            tempo, beats = librosa.beat.beat_track(y=y, sr=sr)
            beat_times = librosa.frames_to_time(beats, sr=sr)
            
            return {
                'bpm': float(tempo),
                'bpm_raw': float(tempo),
                'beats': beats.tolist(),
                'confidence': 0.5,  # 默认置信度
                'beat_positions': beat_times.tolist(),
                'beat_intervals': [],
                'degara_beats': [],
                'beat_loudness': [],
                'onset_rate': 0.0,
                'audio_duration': len(y) / sr,
                'analysis_engine': 'librosa_fallback',
                'quality_score': 0.5
            }
        except Exception as e:
            print(f"备选 BPM 分析也失败: {e}")
            return {
                'bpm': 120.0,  # 默认 BPM
                'error': str(e),
                'analysis_engine': 'fallback_failed'
            }
    
    def _fallback_key_analysis(self, audio_file_path: str) -> Dict:
        """备选调性分析"""
        try:
            y, sr = librosa.load(audio_file_path)
            chroma = librosa.feature.chroma_stft(y=y, sr=sr)
            chroma_mean = np.mean(chroma, axis=1)
            
            # 简单的调性估计
            key_idx = np.argmax(chroma_mean)
            keys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
            estimated_key = keys[key_idx]
            
            return {
                'key': estimated_key,
                'scale': 'major',  # 默认大调
                'strength': float(chroma_mean[key_idx]),
                'algorithm': 'librosa_fallback',
                'alternatives': {},
                'stability_score': 0.5,
                'confidence_level': '低',
                'analysis_engine': 'librosa_fallback'
            }
        except Exception as e:
            print(f"备选调性分析也失败: {e}")
            return {
                'key': 'C',
                'scale': 'major',
                'strength': 0.0,
                'error': str(e),
                'analysis_engine': 'fallback_failed'
            }


# 便捷函数
def quick_analyze(audio_file_path: str) -> Dict:
    """快速分析音频文件"""
    analyzer = EssentiaAnalyzer()
    return analyzer.comprehensive_analysis(audio_file_path)


if __name__ == "__main__":
    # 测试代码
    test_file = "test_chord.wav"
    if os.path.exists(test_file):
        try:
            result = quick_analyze(test_file)
            print("=== Essentia 分析结果 ===")
            print(f"BPM: {result['rhythm_analysis']['bpm']:.1f}")
            print(f"调性: {result['key_analysis']['key']} {result['key_analysis']['scale']}")
            print(f"整体质量: {result['overall_quality']:.2f}")
            print(f"使用建议: {result['recommended_use']}")
        except Exception as e:
            print(f"测试失败: {e}")
    else:
        print(f"测试文件 {test_file} 不存在")
        print("可以使用以下代码创建测试文件:")
        print("python create_test_audio.py")