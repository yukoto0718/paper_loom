from pydantic import BaseModel, Field
from typing import Optional, Dict

class OCRRequest(BaseModel):
    job_id: str = Field(..., description="任务ID")
    ocr_model: str = Field(default="small", description="OCR模型大小 (small/base)")

class OCRResponse(BaseModel):
    job_id: str
    status: str  # processing/completed/failed
    message: str
    result: Optional[Dict] = None

class DownloadResponse(BaseModel):
    download_url: str
    filename: str