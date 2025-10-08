from typing import Optional, Generic, TypeVar, Any
from pydantic import BaseModel
from datetime import datetime

T = TypeVar('T')

class ApiError(BaseModel):
    """API 错误信息模型"""
    code: str
    details: Optional[str] = None

class ApiResponse(BaseModel, Generic[T]):
    """标准 API 响应模型"""
    success: bool
    message: str
    data: Optional[T] = None
    error: Optional[ApiError] = None
    
    @classmethod
    def success_response(cls, message: str, data: Any = None):
        """创建成功响应"""
        return cls(
            success=True,
            message=message,
            data=data,
            error=None
        )
    
    @classmethod
    def error_response(cls, message: str, error_code: str, error_details: str = None):
        """创建错误响应"""
        return cls(
            success=False,
            message=message,
            data=None,
            error=ApiError(code=error_code, details=error_details)
        )

# OCR 特定的数据模型
class UploadResponseData(BaseModel):
    """上传接口返回数据"""
    job_id: str
    filename: str
    file_size: Optional[int] = None
    upload_time: str

class ProcessingResponseData(BaseModel):
    """处理接口返回数据"""
    job_id: str
    status: str
    started_at: Optional[str] = None
    estimated_time: Optional[int] = None

class StatusResponseData(BaseModel):
    """状态查询接口返回数据"""
    job_id: str
    status: str
    progress: Optional[int] = None
    current_step: Optional[str] = None
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    elapsed_time: Optional[int] = None
    stats: Optional[dict] = None

class CleanupResponseData(BaseModel):
    """清理接口返回数据"""
    job_id: str
    cleaned_files: list[str]
