from fastapi import FastAPI, File, UploadFile, HTTPException, BackgroundTasks
from essentia_analyzer import EssentiaAnalyzer, ESSENTIA_AVAILABLE

# 添加缺失的常量
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB
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
import time

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

@app.post("/analyze-essentia")
async def analyze_with_essentia(file: UploadFile = File(...)):
    """使用 Essentia 进行高精度音频分析"""
    if not ESSENTIA_AVAILABLE:
        raise HTTPException(status_code=503, detail="Essentia 引擎不可用，请检查安装")
    
    if not file.filename.lower().endswith(('.mp3', '.wav', '.flac', '.m4a', '.aac')):
        raise HTTPException(status_code=400, detail="不支持的文件格式。支持: mp3, wav, flac, m4a, aac")
    
    # 生成唯一文件名
    file_id = str(uuid.uuid4())
    file_extension = os.path.splitext(file.filename)[1]
    temp_filename = f"{file_id}{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, temp_filename)
    
    try:
        # 保存上传的文件
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # 验证文件大小
        file_size = os.path.getsize(file_path)
        if file_size > MAX_FILE_SIZE:
            raise HTTPException(status_code=413, detail=f"文件太大，最大支持 {MAX_FILE_SIZE/1024/1024:.1f}MB")
        
        # 使用 Essentia 进行分析
        analyzer = EssentiaAnalyzer()
        result = analyzer.comprehensive_analysis(file_path)
        
        # 添加文件信息
        result.update({
            "file_info": {
                "original_filename": file.filename,
                "file_size": file_size,
                "temp_id": file_id
            },
            "api_version": "v1",
            "processing_time": time.time() - result.get('analysis_timestamp', time.time())
        })
        
        return JSONResponse(content=result)
        
    except Exception as e:
        # 记录错误
        print(f"Essentia 分析错误: {str(e)}")
        raise HTTPException(status_code=500, detail=f"分析失败: {str(e)}")
    
    finally:
        # 清理临时文件
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
        except Exception as e:
            print(f"清理临时文件失败: {e}")

@app.get("/essentia-status")
async def essentia_status():
    """检查 Essentia 引擎状态"""
    return {
        "essentia_available": ESSENTIA_AVAILABLE,
        "version": "1.0.0",
        "supported_formats": ["mp3", "wav", "flac", "m4a", "aac"],
        "features": [
            "高精度 BPM 检测",
            "多算法调性分析", 
            "节拍位置检测",
            "音频质量评估"
        ]
    }

@app.post("/analyze-hybrid")
async def analyze_hybrid(file: UploadFile = File(...)):
    """混合分析：Essentia + 传统算法"""
    if not file.filename.lower().endswith(('.mp3', '.wav', '.flac', '.m4a', '.aac')):
        raise HTTPException(status_code=400, detail="不支持的文件格式")
    
    file_id = str(uuid.uuid4())
    file_extension = os.path.splitext(file.filename)[1]
    temp_filename = f"{file_id}{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, temp_filename)
    
    try:
        # 保存文件
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        results = {}
        
        # Essentia 分析 (如果可用)
        if ESSENTIA_AVAILABLE:
            try:
                essentia_analyzer = EssentiaAnalyzer()
                results["essentia"] = essentia_analyzer.comprehensive_analysis(file_path)
            except Exception as e:
                results["essentia"] = {"error": str(e)}
        
        # 传统 librosa 分析
        try:
            from music_analyzer import MusicAnalyzer
            traditional_analyzer = MusicAnalyzer()
            traditional_analyzer.load_audio(file_path)
            
            # 节拍分析
            tempo_result = traditional_analyzer.analyze_tempo_and_beats()
            
            # 和弦进行分析
            chord_progression = traditional_analyzer.analyze_chord_progression()
            
            results["traditional"] = {
                "rhythm_analysis": tempo_result,
                "chord_progression": chord_progression[:10],  # 限制数量
                "analysis_engine": "librosa"
            }
        except Exception as e:
            results["traditional"] = {"error": str(e)}
        
        # 生成比较和推荐
        comparison = _compare_results(results)
        
        return JSONResponse(content={
            "results": results,
            "comparison": comparison,
            "file_info": {
                "original_filename": file.filename,
                "temp_id": file_id
            }
        })
        
    finally:
        # 清理临时文件
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
        except:
            pass

def _compare_results(results: dict) -> dict:
    """比较不同算法的分析结果"""
    comparison = {
        "bpm_comparison": {},
        "key_comparison": {},
        "recommendation": ""
    }
    
    # BPM 比较
    if "essentia" in results and "traditional" in results:
        essentia_bpm = results["essentia"].get("rhythm_analysis", {}).get("bpm", 0)
        traditional_bpm = results["traditional"].get("rhythm_analysis", {}).get("tempo", 0)
        
        if essentia_bpm > 0 and traditional_bpm > 0:
            bpm_diff = abs(essentia_bpm - traditional_bpm)
            comparison["bpm_comparison"] = {
                "essentia_bpm": essentia_bpm,
                "traditional_bpm": traditional_bpm,
                "difference": bpm_diff,
                "agreement": "高" if bpm_diff < 5 else "中" if bpm_diff < 15 else "低"
            }
        
        # 推荐
        if essentia_bpm > 0:
            essentia_quality = results["essentia"].get("overall_quality", 0)
            if essentia_quality > 0.6:
                comparison["recommendation"] = "推荐使用 Essentia 结果（高质量）"
            elif essentia_quality > 0.3:
                comparison["recommendation"] = "Essentia 结果较好，建议验证"
            else:
                comparison["recommendation"] = "两种算法结果差异较大，建议人工确认"
        else:
            comparison["recommendation"] = "使用传统算法结果"
    
    return comparison

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=10814, reload=True)