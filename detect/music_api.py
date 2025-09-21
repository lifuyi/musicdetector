from fastapi import FastAPI, File, UploadFile, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
import os
import uuid
import asyncio
import json
from datetime import datetime
import shutil

# 导入音乐分析器
from music_analyzer import MusicAnalyzer

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

# 存储分析结果
analysis_results: Dict[str, Dict[str, Any]] = {}

# 创建上传目录
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

class AnalysisStatus(BaseModel):
    status: str
    progress: int
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    created_at: datetime
    updated_at: datetime

class AnalysisRequest(BaseModel):
    segment_duration: float = 2.0
    analyze_beats: bool = True
    analyze_chords: bool = True
    analyze_spectral: bool = True

class AnalysisResponse(BaseModel):
    task_id: str
    status: str
    message: str

@app.get("/")
async def root():
    """API根路径"""
    return {
        "message": "音乐分析API服务已启动",
        "version": "1.0.0",
        "endpoints": {
            "upload_audio": "/upload-audio",
            "analysis_status": "/analysis-status/{task_id}",
            "health": "/health"
        }
    }

@app.get("/health")
async def health_check():
    """健康检查"""
    return {"status": "healthy", "timestamp": datetime.now()}

@app.post("/upload-audio", response_model=AnalysisResponse)
async def upload_audio(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    segment_duration: float = 2.0,
    analyze_beats: bool = True,
    analyze_chords: bool = True,
    analyze_spectral: bool = True
):
    """上传音频文件并开始分析"""
    
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
    
    # 初始化分析状态
    analysis_results[task_id] = {
        "status": "processing",
        "progress": 0,
        "result": None,
        "error": None,
        "created_at": datetime.now(),
        "updated_at": datetime.now(),
        "file_path": file_path,
        "filename": file.filename
    }
    
    # 在后台任务中进行分析
    background_tasks.add_task(
        process_audio_analysis,
        task_id,
        file_path,
        segment_duration,
        analyze_beats,
        analyze_chords,
        analyze_spectral
    )
    
    return AnalysisResponse(
        task_id=task_id,
        status="processing",
        message="音频文件上传成功，分析任务已启动"
    )

def process_audio_analysis_sync(
    task_id: str,
    file_path: str,
    segment_duration: float,
    analyze_beats: bool,
    analyze_chords: bool,
    analyze_spectral: bool
):
    """同步处理音频分析任务"""
    try:
        # 更新进度
        analysis_results[task_id]["progress"] = 10
        analysis_results[task_id]["updated_at"] = datetime.now()
        
        # 创建分析器
        analyzer = MusicAnalyzer()
        
        # 加载音频文件
        analysis_results[task_id]["progress"] = 20
        analysis_results[task_id]["updated_at"] = datetime.now()
        
        analyzer.load_audio(file_path)
        
        # 进行实时分析
        analysis_results[task_id]["progress"] = 30
        analysis_results[task_id]["updated_at"] = datetime.now()
        
        segments, beat_info = analyzer.real_time_analysis(segment_duration)
        
        # 整理分析结果
        analysis_results[task_id]["progress"] = 80
        analysis_results[task_id]["updated_at"] = datetime.now()
        
        result = {
            "audio_info": {
                "duration": analyzer.duration,
                "sample_rate": analyzer.sr,
                "filename": analysis_results[task_id]["filename"]
            },
            "beat_analysis": {
                "tempo": beat_info["tempo"],
                "total_beats": len(beat_info["beats"]),
                "total_measures": len(beat_info["measure_starts"]),
                "average_beat_interval": beat_info["average_beat_interval"]
            },
            "segments": segments,
            "summary": {
                "total_segments": len(segments),
                "chords_detected": len([s for s in segments if s.get("chord") and s["chord"] != "Unknown"]),
                "analysis_duration": segment_duration
            }
        }
        
        # 更新最终结果
        analysis_results[task_id]["status"] = "completed"
        analysis_results[task_id]["progress"] = 100
        analysis_results[task_id]["result"] = result
        analysis_results[task_id]["updated_at"] = datetime.now()
        
    except Exception as e:
        analysis_results[task_id]["status"] = "failed"
        analysis_results[task_id]["error"] = str(e)
        analysis_results[task_id]["updated_at"] = datetime.now()
        
        # 清理文件
        if os.path.exists(file_path):
            os.remove(file_path)

async def process_audio_analysis(
    task_id: str,
    file_path: str,
    segment_duration: float,
    analyze_beats: bool,
    analyze_chords: bool,
    analyze_spectral: bool
):
    """异步处理音频分析任务"""
    # 在后台线程中运行同步分析
    await asyncio.to_thread(
        process_audio_analysis_sync,
        task_id,
        file_path,
        segment_duration,
        analyze_beats,
        analyze_chords,
        analyze_spectral
    )

@app.get("/analysis-status/{task_id}", response_model=AnalysisStatus)
async def get_analysis_status(task_id: str):
    """获取分析任务状态"""
    if task_id not in analysis_results:
        raise HTTPException(status_code=404, detail="任务未找到")
    
    result = analysis_results[task_id]
    return AnalysisStatus(
        status=result["status"],
        progress=result["progress"],
        result=result.get("result"),
        error=result.get("error"),
        created_at=result["created_at"],
        updated_at=result["updated_at"]
    )

@app.get("/analysis-result/{task_id}")
async def get_analysis_result(task_id: str):
    """获取完整的分析结果"""
    if task_id not in analysis_results:
        raise HTTPException(status_code=404, detail="任务未找到")
    
    result = analysis_results[task_id]
    if result["status"] != "completed":
        return {
            "status": result["status"],
            "progress": result["progress"],
            "message": "分析尚未完成"
        }
    
    return result["result"]

@app.delete("/analysis-task/{task_id}")
async def delete_analysis_task(task_id: str):
    """删除分析任务"""
    if task_id not in analysis_results:
        raise HTTPException(status_code=404, detail="任务未找到")
    
    # 清理文件
    file_path = analysis_results[task_id].get("file_path")
    if file_path and os.path.exists(file_path):
        os.remove(file_path)
    
    # 删除记录
    del analysis_results[task_id]
    
    return {"message": "任务已删除"}

@app.get("/active-tasks")
async def get_active_tasks():
    """获取活跃任务列表"""
    tasks = []
    for task_id, task_info in analysis_results.items():
        tasks.append({
            "task_id": task_id,
            "status": task_info["status"],
            "progress": task_info["progress"],
            "filename": task_info.get("filename"),
            "created_at": task_info["created_at"],
            "updated_at": task_info["updated_at"]
        })
    
    return {"tasks": tasks, "total": len(tasks)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=10814, reload=True)