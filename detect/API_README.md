# 音乐分析API使用手册

## 项目概述

这是一个基于FastAPI的音乐分析服务，能够对音频文件进行深度分析，包括节拍检测、和弦识别、调性分析、频谱特征提取等功能。提供完整的REST API接口，支持异步处理和实时分析。

## 🎵 功能特性

### 核心分析功能
- **🥁 节拍分析**: 自动检测音乐的BPM和节拍位置
- **🎹 和弦识别**: 识别音乐中的和弦进行（major, minor, dim, aug, 7th, m7, maj7）
- **🎼 调性检测**: 基于和弦走向分析音乐的调式
- **📊 频谱分析**: 提取音频的频谱特征和MFCC特征
- **⚡ 实时分析**: 分段分析音乐，模拟实时处理
- **🔄 异步处理**: 支持后台任务处理，提供进度跟踪

### API特性
- **RESTful设计**: 标准的HTTP接口
- **CORS支持**: 跨域访问支持
- **文件上传**: 支持多种音频格式
- **进度跟踪**: 实时查看分析进度
- **结果缓存**: 分析结果临时存储

## 🚀 API端点

### 1. 服务状态
```http
GET /
```
获取API服务信息和可用端点

**响应示例:**
```json
{
  "message": "音乐分析API服务已启动",
  "version": "1.0.0",
  "endpoints": {
    "upload_audio": "/upload-audio",
    "analysis_status": "/analysis-status/{task_id}",
    "health": "/health"
  }
}
```

### 2. 健康检查
```http
GET /health
```
检查API服务状态

**响应示例:**
```json
{
  "status": "healthy",
  "timestamp": "2025-09-21T17:33:24.045745"
}
```

### 3. 异步音频分析（推荐）
```http
POST /upload-audio
```
上传音频文件并开始异步分析

**请求参数:**
- `file`: 音频文件 (必填)
- `segment_duration`: 分析时间段长度 (可选, 默认2.0秒)
- `analyze_beats`: 是否分析节拍 (可选, 默认true)
- `analyze_chords`: 是否分析和弦 (可选, 默认true)
- `analyze_spectral`: 是否分析频谱 (可选, 默认true)

**响应示例:**
```json
{
  "task_id": "815ba268-881a-44ac-9d18-6072d60d18e8",
  "status": "processing",
  "message": "音频文件上传成功，分析任务已启动"
}
```

### 4. 获取分析状态
```http
GET /analysis-status/{task_id}
```
获取分析任务的当前状态和进度

**响应示例:**
```json
{
  "status": "completed",
  "progress": 100,
  "result": {
    "audio_info": {...},
    "beat_analysis": {...},
    "segments": [...]
  },
  "error": null,
  "created_at": "2025-09-21T17:33:24.045745",
  "updated_at": "2025-09-21T17:33:26.123456"
}
```

### 5. 获取分析结果
```http
GET /analysis-result/{task_id}
```
获取完整的分析结果（仅在任务完成后）

**响应示例:**
```json
{
  "audio_info": {
    "duration": 120.5,
    "sample_rate": 22050,
    "filename": "sample_music.mp3"
  },
  "beat_analysis": {
    "tempo": 128.3,
    "total_beats": 248,
    "total_measures": 62,
    "average_beat_interval": 0.468
  },
  "segments": [
    {
      "start_time": 0.0,
      "end_time": 2.0,
      "notes": ["C4", "E4", "G4"],
      "chord": "Cmajor",
      "spectral_features": {
        "spectral_centroid": 1850.5,
        "spectral_rolloff": 4200.3,
        "zero_crossing_rate": 0.082
      },
      "key": "C major"
    }
  ],
  "summary": {
    "total_segments": 60,
    "chords_detected": 45,
    "analysis_duration": 2.0
  }
}
```

### 6. 获取活跃任务
```http
GET /active-tasks
```
获取当前所有活跃的分析任务列表

**响应示例:**
```json
{
  "tasks": [
    {
      "task_id": "abc123",
      "status": "processing",
      "progress": 65,
      "filename": "song1.mp3",
      "created_at": "2025-09-21T17:30:00.000000",
      "updated_at": "2025-09-21T17:33:00.000000"
    }
  ],
  "total": 1
}
```

### 7. 删除分析任务
```http
DELETE /analysis-task/{task_id}
```
删除指定的分析任务和相关文件

**响应示例:**
```json
{
  "message": "任务已删除"
}
```

### 8. 同步音频分析（简化版）
```http
POST /analyze-sync
```
上传音频文件并进行同步分析（适用于小文件）

**请求参数:**
- `file`: 音频文件 (必填)
- `segment_duration`: 分析时间段长度 (可选, 默认1.0秒)

**响应示例:**
```json
{
  "task_id": "815ba268-881a-44ac-9d18-6072d60d18e8",
  "status": "completed",
  "message": "音频分析完成",
  "result": {
    "audio_info": {
      "duration": 2.00,
      "sample_rate": 22050,
      "filename": "test_chord.wav"
    },
    "beat_analysis": {
      "tempo": 120.5,
      "total_beats": 8,
      "beat_times": [0.12, 0.58, 1.03, 1.49]
    },
    "segments": [
      {
        "start_time": 0.0,
        "end_time": 1.0,
        "notes": ["B2", "E2", "G#2"],
        "chord": "Emajor"
      }
    ],
    "summary": {
      "total_segments": 2,
      "chords_detected": 2,
      "analysis_duration": 1.0
    }
  }
}
```

## 📁 支持的音频格式

- **WAV** - 无损音频，最佳分析效果
- **MP3** - 压缩音频，广泛支持
- **M4A/AAC** - Apple格式
- **FLAC** - 无损压缩
- **OGG** - 开源格式
- **WMA** - Windows媒体音频

## 🛠️ 安装和运行

### 系统要求
- Python 3.8+
- 2GB+ RAM (推荐4GB+)
- 支持音频处理的系统环境

### 1. 安装依赖
```bash
# 创建虚拟环境（推荐）
python -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate  # Windows

# 安装核心依赖
pip install fastapi uvicorn python-multipart

# 安装音频处理依赖
pip install librosa numpy matplotlib scikit-learn

# 或者使用requirements.txt（如果存在）
pip install -r requirements.txt
```

### 2. 启动服务

#### 启动完整功能API（推荐）
```bash
# 标准启动
uvicorn music_api:app --host 0.0.0.0 --port 10814

# 开发模式（自动重载）
uvicorn music_api:app --host 0.0.0.0 --port 10814 --reload

# 生产模式（多进程）
uvicorn music_api:app --host 0.0.0.0 --port 10814 --workers 4
```

#### 启动简化版API
```bash
uvicorn music_api_simple:app --host 0.0.0.0 --port 10814 --reload
```

### 3. 验证服务状态
```bash
# 健康检查
curl http://localhost:10814/health

# 获取API信息
curl http://localhost:10814/
```

### 4. 测试API
```bash
# 运行完整测试
python test_api.py

# 运行简化测试
python test_simple_api.py
```

## 💻 使用示例

### Python客户端示例

#### 异步分析（推荐）
```python
import requests
import time

def analyze_audio_async(file_path, segment_duration=2.0):
    """异步分析音频文件"""
    
    # 1. 上传文件并开始分析
    with open(file_path, 'rb') as f:
        files = {'file': (file_path, f, 'audio/mpeg')}
        data = {
            'segment_duration': segment_duration,
            'analyze_beats': True,
            'analyze_chords': True,
            'analyze_spectral': True
        }
        
        response = requests.post('http://localhost:10814/upload-audio', 
                               files=files, data=data)
    
    if response.status_code != 200:
        print(f"上传失败: {response.text}")
        return None
    
    upload_result = response.json()
    task_id = upload_result['task_id']
    print(f"任务已创建: {task_id}")
    
    # 2. 轮询检查状态
    while True:
        status_response = requests.get(f'http://localhost:10814/analysis-status/{task_id}')
        if status_response.status_code != 200:
            print(f"获取状态失败: {status_response.text}")
            return None
        
        status = status_response.json()
        print(f"进度: {status['progress']}% - {status['status']}")
        
        if status['status'] == 'completed':
            # 3. 获取最终结果
            result_response = requests.get(f'http://localhost:10814/analysis-result/{task_id}')
            if result_response.status_code == 200:
                return result_response.json()
            break
        elif status['status'] == 'failed':
            print(f"分析失败: {status.get('error', '未知错误')}")
            return None
        
        time.sleep(1)  # 等待1秒后再次检查
    
    return None

# 使用示例
result = analyze_audio_async('your_music.mp3', segment_duration=2.0)
if result:
    print(f"音频时长: {result['audio_info']['duration']}秒")
    print(f"BPM: {result['beat_analysis']['tempo']}")
    print(f"和弦进行: {[s['chord'] for s in result['segments'] if s.get('chord')]}")
```

#### 同步分析（简化版）
```python
import requests

def analyze_audio_sync(file_path, segment_duration=1.0):
    """同步分析音频文件"""
    
    with open(file_path, 'rb') as f:
        files = {'file': (file_path, f, 'audio/mpeg')}
        data = {'segment_duration': segment_duration}
        
        response = requests.post('http://localhost:10814/analyze-sync', 
                               files=files, data=data)
    
    if response.status_code == 200:
        return response.json()
    else:
        print(f"分析失败: {response.text}")
        return None

# 快速分析
result = analyze_audio_sync('test_chord.wav', segment_duration=1.0)
if result:
    print(f"检测到的速度: {result['result']['beat_analysis']['tempo']} BPM")
    print(f"和弦进行: {[s['chord'] for s in result['result']['segments']]}")
```

### JavaScript/前端示例
```javascript
// 异步分析音频文件
async function analyzeAudio(file, segmentDuration = 2.0) {
    const formData = new FormData();
    formData.append('file', file);
    formData.append('segment_duration', segmentDuration);
    formData.append('analyze_beats', true);
    formData.append('analyze_chords', true);
    formData.append('analyze_spectral', true);
    
    try {
        // 1. 上传文件
        const uploadResponse = await fetch('http://localhost:10814/upload-audio', {
            method: 'POST',
            body: formData
        });
        
        if (!uploadResponse.ok) {
            throw new Error('文件上传失败');
        }
        
        const { task_id } = await uploadResponse.json();
        console.log(`分析任务已创建: ${task_id}`);
        
        // 2. 轮询状态
        const checkStatus = async () => {
            const statusResponse = await fetch(`http://localhost:10814/analysis-status/${task_id}`);
            const status = await statusResponse.json();
            
            console.log(`进度: ${status.progress}% - ${status.status}`);
            
            if (status.status === 'completed') {
                // 3. 获取结果
                const resultResponse = await fetch(`http://localhost:10814/analysis-result/${task_id}`);
                const result = await resultResponse.json();
                return result;
            } else if (status.status === 'failed') {
                throw new Error(status.error || '分析失败');
            }
            
            // 继续轮询
            return new Promise(resolve => setTimeout(() => resolve(checkStatus()), 1000));
        };
        
        return await checkStatus();
        
    } catch (error) {
        console.error('分析过程出错:', error);
        return null;
    }
}

// 使用示例
const fileInput = document.getElementById('audioFile');
fileInput.addEventListener('change', async (event) => {
    const file = event.target.files[0];
    if (file) {
        const result = await analyzeAudio(file);
        if (result) {
            console.log('分析完成:', result);
            document.getElementById('bpm').textContent = result.beat_analysis.tempo;
            document.getElementById('duration').textContent = result.audio_info.duration;
        }
    }
});
```

### cURL示例

#### 异步分析
```bash
# 1. 上传音频文件
curl -X POST "http://localhost:10814/upload-audio" \
  -F "file=@your_music.mp3" \
  -F "segment_duration=2.0" \
  -F "analyze_beats=true" \
  -F "analyze_chords=true" \
  -F "analyze_spectral=true"

# 响应: {"task_id": "abc123", "status": "processing", "message": "..."}

# 2. 检查状态
curl "http://localhost:10814/analysis-status/abc123"

# 3. 获取结果（状态为completed后）
curl "http://localhost:10814/analysis-result/abc123"
```

#### 同步分析（快速测试）
```bash
# 直接分析音频文件
curl -X POST "http://localhost:10814/analyze-sync" \
  -F "file=@test_chord.wav" \
  -F "segment_duration=1.0"
```

#### 管理任务
```bash
# 查看所有活跃任务
curl "http://localhost:10814/active-tasks"

# 删除任务
curl -X DELETE "http://localhost:10814/analysis-task/abc123"
```

## 📊 分析结果详解

### 音频信息 (audio_info)
```json
{
  "audio_info": {
    "duration": 120.5,        // 音频时长（秒）
    "sample_rate": 22050,     // 采样率（Hz）
    "filename": "song.mp3"    // 原始文件名
  }
}
```

### 节拍分析 (beat_analysis)
```json
{
  "beat_analysis": {
    "tempo": 128.3,                    // 速度（BPM）
    "total_beats": 248,                // 总节拍数
    "total_measures": 62,              // 总小节数
    "average_beat_interval": 0.468     // 平均节拍间隔（秒）
  }
}
```

### 时间段分析 (segments)
每个时间段包含详细的音乐分析信息：
```json
{
  "segments": [
    {
      "start_time": 0.0,         // 开始时间（秒）
      "end_time": 2.0,           // 结束时间（秒）
      "notes": ["C4", "E4", "G4"], // 检测到的音符列表
      "chord": "Cmajor",         // 识别的和弦类型
      "key": "C major",          // 调性分析结果
      "spectral_features": {     // 频谱特征
        "spectral_centroid": 1850.5,
        "spectral_rolloff": 4200.3,
        "zero_crossing_rate": 0.082,
        "mfccs": [/* 13个MFCC系数 */],
        "chroma": [/* 12个半音色度特征 */]
      },
      "rhythm_pattern": {        // 节奏模式
        "onset_count": 12,
        "onset_times": [0.1, 0.3, 0.5, /* ... */],
        "rhythm_complexity": 0.75,
        "onset_strength": 0.82
      }
    }
  ]
}
```

### 和弦类型说明
支持识别的和弦类型：
- **major** (大调): [0, 4, 7] - 例如 Cmajor (C-E-G)
- **minor** (小调): [0, 3, 7] - 例如 Cminor (C-Eb-G)
- **dim** (减和弦): [0, 3, 6] - 例如 Cdim (C-Eb-Gb)
- **aug** (增和弦): [0, 4, 8] - 例如 Caug (C-E-G#)
- **7th** (七和弦): [0, 4, 7, 10] - 例如 C7 (C-E-G-Bb)
- **m7** (小七和弦): [0, 3, 7, 10] - 例如 Cm7 (C-Eb-G-Bb)
- **maj7** (大七和弦): [0, 4, 7, 11] - 例如 Cmaj7 (C-E-G-B)

### 频谱特征说明
- **spectral_centroid**: 频谱质心，表示音频的"亮度"
- **spectral_rolloff**: 频谱滚降点，表示高频成分的比例
- **zero_crossing_rate**: 零交叉率，与音频的噪声特性相关
- **mfccs**: Mel频率倒谱系数，13个系数表示音频的音色特征
- **chroma**: 色度特征，12个半音的强度分布

### 总结信息 (summary)
```json
{
  "summary": {
    "total_segments": 60,      // 总分析段数
    "chords_detected": 45,     // 成功识别的和弦数
    "analysis_duration": 2.0,  // 每段分析时长（秒）
    "processing_time": 15.3    // 总处理时间（秒）
  }
}

## 注意事项

1. **音频质量**: 分析结果受音频质量影响，建议使用清晰的音频文件
2. **处理时间**: 分析时间取决于音频长度和复杂度
3. **和弦识别**: 对于复杂音乐，和弦识别可能不够准确
4. **节拍检测**: 对于节奏不明显的音乐，节拍检测可能不准确

## 扩展功能

完整的音乐分析器还包含以下高级功能：
- 实时频谱分析
- 调性检测
- 音乐风格分类
- 音频可视化

## 错误处理

API可能返回以下错误：
- `400 Bad Request`: 无效的文件格式或参数
- `500 Internal Server Error`: 分析过程出错

## 性能优化建议

1. 对于长音频文件，建议增加`segment_duration`参数
2. 可以限制同时处理的文件数量
3. 考虑使用缓存机制避免重复分析
4. 对于生产环境，建议使用异步处理模式

## 联系我们

如有问题或建议，请通过以下方式联系：
- 提交Issue
- 发送邮件
- 技术讨论