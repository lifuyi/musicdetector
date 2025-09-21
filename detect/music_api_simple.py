from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
import os
import uuid
import json
from datetime import datetime
import shutil

# 导入音乐分析器
from music_analyzer import MusicAnalyzer
import librosa

app = FastAPI(
    title="音乐分析API",
    description="提供音乐和弦、节拍、调性分析的REST API",
    version="1.0.0"
)

# 添加CORS支持
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 创建上传目录
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

class AnalysisResponse(BaseModel):
    task_id: str
    status: str
    message: str
    result: Optional[Dict[str, Any]] = None

@app.get("/")
async def root():
    """API根路径"""
    return {
        "message": "音乐分析API服务已启动",
        "version": "1.0.0",
        "endpoints": {
            "upload_audio": "/upload-audio",
            "analysis_sync": "/analyze-sync",
            "health": "/health"
        }
    }

@app.get("/health")
async def health_check():
    """健康检查"""
    return {"status": "healthy", "timestamp": datetime.now()}

@app.post("/analyze-sync", response_model=AnalysisResponse)
async def analyze_audio_sync(
    file: UploadFile = File(...),
    segment_duration: float = 1.0
):
    """同步分析音频文件（简化版本）"""
    
    # 验证文件类型
    if not file.content_type or not file.content_type.startswith("audio/"):
        raise HTTPException(status_code=400, detail="请上传有效的音频文件")
    
    # 生成任务ID
    task_id = str(uuid.uuid4())
    
    # 保存文件
    file_extension = os.path.splitext(file.filename)[1] if file.filename else ".wav"
    file_path = os.path.join(UPLOAD_DIR, f"{task_id}{file_extension}")
    
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"文件保存失败: {str(e)}")
    
    try:
        # 创建分析器
        analyzer = MusicAnalyzer()
        
        # 加载音频文件
        analyzer.load_audio(file_path)
        
        # 进行基础分析（简化版，不打印详细信息）
        tempo, beats = librosa.beat.beat_track(y=analyzer.y, sr=analyzer.sr)
        beat_times = librosa.frames_to_time(beats, sr=analyzer.sr)
        
        # 分析前几个时间段的和弦
        segments = []
        num_segments = min(5, int(analyzer.duration / segment_duration))  # 限制分析段数
        
        for i in range(num_segments):
            start_time = i * segment_duration
            notes = analyzer.detect_pitch(start_time, segment_duration)
            chord = analyzer.identify_chord(notes) if notes else None
            
            segments.append({
                'start_time': start_time,
                'end_time': start_time + segment_duration,
                'notes': notes,
                'chord': chord
            })
        
        # 构建结果
        result = {
            "audio_info": {
                "duration": analyzer.duration,
                "sample_rate": analyzer.sr,
                "filename": file.filename
            },
            "beat_analysis": {
                "tempo": float(tempo),
                "total_beats": len(beats),
                "beat_times": beat_times[:10].tolist()  # 只返回前10个节拍时间
            },
            "segments": segments,
            "summary": {
                "total_segments": len(segments),
                "chords_detected": len([s for s in segments if s.get("chord") and s["chord"] != "Unknown"]),
                "analysis_duration": segment_duration
            }
        }
        
        # 清理文件
        if os.path.exists(file_path):
            os.remove(file_path)
        
        return AnalysisResponse(
            task_id=task_id,
            status="completed",
            message="音频分析完成",
            result=result
        )
        
    except Exception as e:
        # 清理文件
        if os.path.exists(file_path):
            os.remove(file_path)
        
        raise HTTPException(status_code=500, detail=f"分析过程出错: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=10814, reload=True)