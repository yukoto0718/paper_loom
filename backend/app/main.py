from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
from loguru import logger
import sys
from pathlib import Path

# 确保能找到 app 模块
app_dir = Path(__file__).parent
backend_dir = app_dir.parent
project_root = backend_dir.parent  # paper-loom-backend/

if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from app.core.config import settings
from app.core.model_manager import model_manager
from app.api.v1 import ocr

# 配置日志
logs_dir = backend_dir / "logs"
logs_dir.mkdir(exist_ok=True)

logger.add(
    logs_dir / "app.log",
    rotation="500 MB",
    retention="10 days",
    level="INFO"
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用启动和关闭时的处理"""
    # 启动时：检查模型
    logger.info("正在检查 MinerU...")
    await model_manager.download_models_if_needed()
    logger.info("✅ 准备完成")

    yield

    # 关闭时的清理工作
    logger.info("应用关闭")


# 创建 FastAPI 应用
app = FastAPI(
    title=settings.PROJECT_NAME,
    description="学术论文 PDF 转 Markdown 工具（基于 MinerU 架构）",
    version="1.0.0",
    lifespan=lifespan
)

# CORS 配置（允许前端访问）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应限制具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 挂载静态文件（前端） - 使用绝对路径
frontend_dir = project_root / "frontend"
if frontend_dir.exists():
    app.mount("/static", StaticFiles(directory=str(frontend_dir)), name="static")
    logger.info(f"✅ 前端目录已挂载: {frontend_dir}")
else:
    logger.warning(f"⚠️ 前端目录不存在: {frontend_dir}")

# 挂载输出文件（用于下载图片）
outputs_dir = project_root / "data" / "outputs"
outputs_dir.mkdir(parents=True, exist_ok=True)
app.mount("/outputs", StaticFiles(directory=str(outputs_dir)), name="outputs")

# 注册路由
app.include_router(ocr.router, prefix=settings.API_V1_PREFIX)


@app.get("/", tags=["Root"])
async def root():
    """健康检查"""
    return {
        "message": "Paper-Loom OCR API",
        "status": "running",
        "docs": "/docs",
        "frontend": "/static/index.html" if frontend_dir.exists() else "前端未配置"
    }


@app.get("/health", tags=["Root"])
async def health_check():
    """健康检查接口"""
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn

    # 使用字符串导入方式（支持 reload）
    uvicorn.run(
        "app.main:app",  # 改为字符串
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )