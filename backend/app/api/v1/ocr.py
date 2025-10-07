import asyncio
import uuid
from pathlib import Path
from fastapi import APIRouter, UploadFile, File, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse

from app.core.config import settings
from app.schemas.ocr_schemas import OCRRequest, OCRResponse, DownloadResponse
from app.modules.ocr.ocr_pipeline import OCRPipeline
from loguru import logger

router = APIRouter(prefix="/ocr", tags=["OCR"])

# 任务状态存储（生产环境应使用Redis）
job_status = {}


@router.post("/upload", summary="上传PDF文件")
async def upload_pdf(file: UploadFile = File(...)):
    """
    上传PDF文件，返回job_id
    """
    # 验证文件类型
    if not file.filename.endswith('.pdf'):
        raise HTTPException(status_code=400, detail="只支持PDF文件")

    # 验证文件大小
    content = await file.read()
    if len(content) > settings.MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail=f"文件过大，最大支持{settings.MAX_FILE_SIZE // 1024 // 1024}MB")

    # 生成job_id
    job_id = str(uuid.uuid4())

    # 保存文件
    upload_path = settings.UPLOADS_DIR / f"{job_id}.pdf"
    upload_path.write_bytes(content)

    # 初始化任务状态
    job_status[job_id] = {
        'status': 'uploaded',
        'filename': file.filename,
        'message': '文件上传成功'
    }

    logger.info(f"文件上传成功: {file.filename} (job_id: {job_id})")

    return {
        'job_id': job_id,
        'filename': file.filename,
        'message': '文件上传成功，请调用 /process 接口开始处理'
    }


@router.post("/process", response_model=OCRResponse, summary="开始处理PDF")
async def process_pdf(request: OCRRequest, background_tasks: BackgroundTasks):
    """
    开始处理PDF，返回处理状态
    """
    job_id = request.job_id

    # 检查job_id是否存在
    if job_id not in job_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    # 检查文件是否存在
    pdf_path = settings.UPLOADS_DIR / f"{job_id}.pdf"
    if not pdf_path.exists():
        raise HTTPException(status_code=404, detail="PDF文件不存在")

    # 更新状态为处理中
    job_status[job_id]['status'] = 'processing'
    job_status[job_id]['message'] = '正在处理中...'

    # 异步处理（后台任务）
    background_tasks.add_task(
        process_pdf_task,
        job_id,
        pdf_path,
        request.ocr_model
    )

    return OCRResponse(
        job_id=job_id,
        status='processing',
        message='处理已开始，请使用job_id查询结果'
    )


async def process_pdf_task(job_id: str, pdf_path: Path, ocr_model: str):
    """
    后台任务：处理PDF
    """
    try:
        logger.info(f"开始处理任务: {job_id}")
        
        # 创建输出目录
        output_dir = settings.OUTPUTS_DIR / job_id
        output_dir.mkdir(exist_ok=True)
        
        # ✅ 创建简化的 Pipeline
        pipeline = OCRPipeline(ocr_model_size=ocr_model)
        
        # ✅ 处理（所有复杂逻辑在 MinerU 内部）
        result = await pipeline.process(pdf_path, output_dir)
        
        # 更新状态
        job_status[job_id].update({
            'status': 'completed',
            'message': '处理完成',
            'result': result
        })
        
        logger.info(f"任务完成: {job_id}")
        
    except Exception as e:
        error_msg = str(e) if str(e) else f"未知错误: {type(e).__name__}"
        logger.error(f"任务失败 {job_id}: {error_msg}")
        import traceback
        logger.error(f"详细错误信息: {traceback.format_exc()}")
        job_status[job_id].update({
            'status': 'failed',
            'message': f'处理失败: {error_msg}'
        })
        

@router.get("/status/{job_id}", response_model=OCRResponse, summary="查询处理状态")
async def get_status(job_id: str):
    """
    查询任务处理状态
    """
    if job_id not in job_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    status = job_status[job_id]

    return OCRResponse(
        job_id=job_id,
        status=status['status'],
        message=status['message'],
        result=status.get('result')
    )


@router.get("/result/{job_id}", summary="获取Markdown结果")
async def get_result(job_id: str):
    """
    获取处理后的Markdown内容
    """
    if job_id not in job_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    status = job_status[job_id]

    if status['status'] != 'completed':
        raise HTTPException(status_code=400, detail=f"任务尚未完成，当前状态: {status['status']}")

    # 读取MD文件
    md_file = settings.OUTPUTS_DIR / job_id / "output.md"
    if not md_file.exists():
        raise HTTPException(status_code=404, detail="Markdown文件不存在")

    markdown_content = md_file.read_text(encoding='utf-8')

    return {
        'job_id': job_id,
        'markdown': markdown_content,
        'stats': status['result']['stats'],
        'download_url': f"/api/v1/ocr/download/{job_id}"
    }


@router.get("/download/{job_id}", summary="下载Markdown文件")
async def download_markdown(job_id: str):
    """
    下载生成的Markdown文件
    """
    if job_id not in job_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    status = job_status[job_id]

    if status['status'] != 'completed':
        raise HTTPException(status_code=400, detail="任务尚未完成")

    md_file = settings.OUTPUTS_DIR / job_id / "output.md"
    if not md_file.exists():
        raise HTTPException(status_code=404, detail="文件不存在")

    # 生成下载文件名
    original_filename = status.get('filename', 'document.pdf')
    download_filename = original_filename.replace('.pdf', '_output.md')

    return FileResponse(
        path=md_file,
        filename=download_filename,
        media_type='text/markdown'
    )
