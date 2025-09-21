import librosa
import numpy as np
import matplotlib.pyplot as plt
from sklearn.cluster import KMeans

class MusicAnalyzer:
    def __init__(self):
        # 初始化音符与频率的映射
        self.note_frequencies = self._create_note_frequency_map()
        # 和弦类型识别规则
        self.chord_patterns = self._create_chord_patterns()
        
    def _create_note_frequency_map(self):
        """创建音符到频率的映射"""
        notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
        base_freq = 440.0  # A4的频率
        note_map = {}
        
        for i in range(88):  # 钢琴88个键
            note = notes[i % 12]
            octave = (i // 12) - 1  # A4是第49个键，对应octave 4
            freq = base_freq * 2 **((i - 49) / 12)
            note_map[f"{note}{octave}"] = freq
            
        return note_map
    
    def _create_chord_patterns(self):
        """定义和弦的音程模式（半音数）"""
        return {
            'major': [0, 4, 7],
            'minor': [0, 3, 7],
            'dim': [0, 3, 6],
            'aug': [0, 4, 8],
            '7th': [0, 4, 7, 10],
            'm7': [0, 3, 7, 10],
            'maj7': [0, 4, 7, 11]
        }
    
    def load_audio(self, file_path):
        """加载音频文件"""
        self.y, self.sr = librosa.load(file_path)
        # 计算音频时长
        self.duration = librosa.get_duration(y=self.y, sr=self.sr)
        print(f"加载音频成功，时长: {self.duration:.2f}秒，采样率: {self.sr}Hz")
        return self
    
    def detect_pitch(self, start_time, duration=0.5):
        """检测指定时间段内的主要音高"""
        start_sample = int(start_time * self.sr)
        end_sample = int((start_time + duration) * self.sr)
        segment = self.y[start_sample:end_sample]
        
        # 使用STFT分析频谱
        stft = np.abs(librosa.stft(segment))
        frequencies = librosa.fft_frequencies(sr=self.sr)
        
        # 找到最强的几个频率
        max_indices = np.argsort(stft.sum(axis=1))[::-1][:5]  # 取前5个最强频率
        dominant_freqs = frequencies[max_indices]
        
        # 将频率转换为最接近的音符
        notes = []
        for freq in dominant_freqs:
            if freq < 20:  # 忽略过低频率
                continue
            # 找到最接近的音符
            closest_note = min(self.note_frequencies.items(), 
                              key=lambda x: abs(np.log2(freq/x[1])))
            notes.append(closest_note[0])
            
        return list(set(notes))  # 去重
    
    def identify_chord(self, notes):
        """根据音符识别和弦类型"""
        if len(notes) < 3:
            return None
            
        # 提取音名和八度
        note_names = [n[:-1] for n in notes]
        octaves = [int(n[-1]) for n in notes]
        
        # 转换为相对音高（0-11）
        note_values = {'C':0, 'C#':1, 'D':2, 'D#':3, 'E':4, 'F':5, 
                      'F#':6, 'G':7, 'G#':8, 'A':9, 'A#':10, 'B':11}
        values = [note_values[name] for name in note_names]
        
        # 尝试识别和弦类型
        for root_idx in range(len(values)):
            root = values[root_idx]
            # 计算相对于根音的音程
            intervals = [(v - root) % 12 for v in values]
            
            # 检查是否匹配已知和弦模式
            for chord_type, pattern in self.chord_patterns.items():
                if all(interval in intervals for interval in pattern):
                    root_note = notes[root_idx]
                    return f"{root_note[:-1]}{chord_type}"
        
        return "Unknown"
    
    def analyze_chord_progression(self, segment_duration=0.5):
        """分析整个音频的和弦走向"""
        num_segments = int(self.duration / segment_duration)
        chord_progression = []
        
        for i in range(num_segments):
            start_time = i * segment_duration
            notes = self.detect_pitch(start_time, segment_duration)
            if notes:
                chord = self.identify_chord(notes)
                if chord:
                    chord_progression.append({
                        'time': start_time,
                        'chord': chord,
                        'notes': notes
                    })
        
        return chord_progression
    
    def detect_key(self, chord_progression):
        """根据和弦走向检测调性"""
        # 简单实现：统计出现最多的和弦根音
        if not chord_progression:
            return None
            
        roots = [chord['chord'][:1] if '#' not in chord['chord'] else chord['chord'][:2] 
                for chord in chord_progression]
        
        # 统计根音出现频率
        from collections import Counter
        root_counts = Counter(roots)
        most_common_root = root_counts.most_common(1)[0][0]
        
        # 简单判断大调还是小调（实际应用中需要更复杂的逻辑）
        minor_chords = sum(1 for c in chord_progression if 'minor' in c['chord'] or 'm7' in c['chord'])
        major_chords = len(chord_progression) - minor_chords
        
        key_type = 'major' if major_chords >= minor_chords else 'minor'
        return f"{most_common_root} {key_type}"
    
    def analyze_tempo_and_beats(self):
        """分析节拍和速度"""
        print("正在分析节拍和速度...")
        
        # 使用librosa的节拍检测
        tempo, beats = librosa.beat.beat_track(y=self.y, sr=self.sr)
        
        # 将节拍转换为时间
        beat_times = librosa.frames_to_time(beats, sr=self.sr)
        
        print(f"检测到的速度: {tempo:.1f} BPM")
        print(f"检测到 {len(beats)} 个节拍")
        
        # 分析小节结构（假设4/4拍）
        beat_intervals = np.diff(beat_times)
        average_beat_interval = np.mean(beat_intervals)
        
        # 计算每小节的开始时间（每4拍为一个小节）
        measure_starts = beat_times[::4]  # 每4拍取一个
        
        print(f"平均节拍间隔: {average_beat_interval:.3f} 秒")
        print(f"检测到 {len(measure_starts)} 个小节")
        
        return {
            'tempo': tempo,
            'beats': beats,
            'beat_times': beat_times,
            'measure_starts': measure_starts,
            'average_beat_interval': average_beat_interval
        }
    
    def analyze_spectral_features(self, start_time, duration=2.0):
        """分析频谱特征"""
        start_sample = int(start_time * self.sr)
        end_sample = int((start_time + duration) * self.sr)
        segment = self.y[start_sample:end_sample]
        
        # 计算频谱质心
        spectral_centroids = librosa.feature.spectral_centroid(y=segment, sr=self.sr)[0]
        
        # 计算频谱滚降点
        spectral_rolloff = librosa.feature.spectral_rolloff(y=segment, sr=self.sr)[0]
        
        # 计算零交叉率
        zero_crossing_rate = librosa.feature.zero_crossing_rate(segment)[0]
        
        # 计算MFCC特征
        mfccs = librosa.feature.mfcc(y=segment, sr=self.sr, n_mfcc=13)
        
        # 计算色度特征
        chroma = librosa.feature.chroma_stft(y=segment, sr=self.sr)
        
        return {
            'spectral_centroid': np.mean(spectral_centroids),
            'spectral_rolloff': np.mean(spectral_rolloff),
            'zero_crossing_rate': np.mean(zero_crossing_rate),
            'mfccs': np.mean(mfccs, axis=1),
            'chroma': np.mean(chroma, axis=1)
        }
    
    def analyze_rhythm_pattern(self, start_time, duration=2.0):
        """分析节奏模式"""
        start_sample = int(start_time * self.sr)
        end_sample = int((start_time + duration) * self.sr)
        segment = self.y[start_sample:end_sample]
        
        # 计算 onset 强度
        onset_env = librosa.onset.onset_strength(y=segment, sr=self.sr)
        
        # 检测 onset 点
        onsets = librosa.onset.onset_detect(onset_envelope=onset_env, sr=self.sr)
        
        # 计算节奏复杂度
        if len(onsets) > 1:
            onset_intervals = np.diff(onsets)
            rhythm_complexity = np.std(onset_intervals) / np.mean(onset_intervals) if np.mean(onset_intervals) > 0 else 0
        else:
            rhythm_complexity = 0
        
        return {
            'onset_count': len(onsets),
            'onset_times': librosa.frames_to_time(onsets, sr=self.sr),
            'rhythm_complexity': rhythm_complexity,
            'onset_strength': np.mean(onset_env)
        }
    
    def real_time_analysis(self, segment_duration=2.0):
        """增强的实时分析模式 - 逐步分析音乐"""
        print("\n=== 开始增强实时分析模式 ===")
        print(f"音频总时长: {self.duration:.2f} 秒")
        
        # 首先分析节拍
        beat_info = self.analyze_tempo_and_beats()
        
        print(f"\n开始逐步分析，每段 {segment_duration} 秒...")
        
        num_segments = int(self.duration / segment_duration)
        all_segments = []
        
        for i in range(num_segments):
            start_time = i * segment_duration
            end_time = min((i + 1) * segment_duration, self.duration)
            
            print(f"\n--- 分析时间段: {start_time:.1f}s - {end_time:.1f}s ---")
            
            # 分析当前时间段的节拍
            current_beats = beat_info['beat_times'][
                (beat_info['beat_times'] >= start_time) & 
                (beat_info['beat_times'] < end_time)
            ]
            
            print(f"当前时间段节拍数: {len(current_beats)}")
            if len(current_beats) > 0:
                print(f"节拍时间: {[f'{bt:.2f}' for bt in current_beats[:5]]}")
                if len(current_beats) > 5:
                    print("...")
            
            # 分析频谱特征
            spectral_features = self.analyze_spectral_features(start_time, segment_duration)
            print(f"频谱质心: {spectral_features['spectral_centroid']:.1f} Hz")
            print(f"频谱滚降点: {spectral_features['spectral_rolloff']:.1f} Hz")
            
            # 分析节奏模式
            rhythm_pattern = self.analyze_rhythm_pattern(start_time, segment_duration)
            print(f"Onset数量: {rhythm_pattern['onset_count']}")
            print(f"节奏复杂度: {rhythm_pattern['rhythm_complexity']:.3f}")
            
            # 分析音高和和弦
            notes = self.detect_pitch(start_time, segment_duration)
            if notes:
                chord = self.identify_chord(notes)
                print(f"检测到的音符: {notes}")
                print(f"识别的和弦: {chord}")
            else:
                print("未检测到清晰的音符")
                chord = None
            
            # 分析节奏特征
            if len(current_beats) > 1:
                beat_intervals = np.diff(current_beats)
                if len(beat_intervals) > 0:
                    avg_interval = np.mean(beat_intervals)
                    print(f"平均节拍间隔: {avg_interval:.3f}s")
            
            # 小节分析
            measures_in_segment = len(current_beats) // 4  # 假设4/4拍
            if measures_in_segment > 0:
                print(f"检测到约 {measures_in_segment} 个小节")
            
            segment_info = {
                'start_time': start_time,
                'end_time': end_time,
                'beats': current_beats.tolist() if len(current_beats) > 0 else [],
                'notes': notes,
                'chord': chord,
                'spectral_features': spectral_features,
                'rhythm_pattern': rhythm_pattern,
                'estimated_measures': measures_in_segment
            }
            all_segments.append(segment_info)
            
            # 模拟实时分析的延迟
            import time
            time.sleep(0.1)
        
        print(f"\n=== 分析完成 ===")
        print(f"总共分析了 {len(all_segments)} 个时间段")
        
        return all_segments, beat_info

# 使用示例
if __name__ == "__main__":
    analyzer = MusicAnalyzer()
    
    try:
        # 尝试加载音频文件
        audio_file = "sample_music.mp3"
        print(f"尝试加载音频文件: {audio_file}")
        analyzer.load_audio(audio_file)
        
        # 分析和弦走向
        progression = analyzer.analyze_chord_progression()
        print("和弦走向:")
        for segment in progression[:10]:  # 只显示前10个片段
            print(f"{segment['time']:.1f}s: {segment['chord']} ({', '.join(segment['notes'])})")
        
        # 检测调性
        key = analyzer.detect_key(progression)
        print(f"\n检测到的调性: {key}")
        
    except FileNotFoundError:
        print(f"音频文件 '{audio_file}' 未找到")
        print("请确保音频文件存在于当前目录，或使用以下方式测试:")
        print("1. 将音频文件重命名为 'sample_music.mp3'")
        print("2. 修改代码中的文件名")
        print("3. 使用 librosa 自带的示例音频进行测试")
        
        # 提供测试示例
        print("\n=== 功能演示模式 ===")
        print("音符频率映射示例:")
        sample_notes = ['C4', 'E4', 'G4']  # C大调和弦
        print(f"音符 {sample_notes} 识别的和弦: {analyzer.identify_chord(sample_notes)}")
        
        print("\n和弦模式定义:")
        for chord_type, pattern in analyzer.chord_patterns.items():
            print(f"{chord_type}: {pattern}")
            
    except Exception as e:
        print(f"分析出错: {str(e)}")
        print(f"错误类型: {type(e).__name__}")
