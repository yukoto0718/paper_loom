from pathlib import Path
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # 项目路径
    PROJECT_ROOT: Path = Path(__file__).parent.parent.parent.parent
    MODELS_DIR: Path = PROJECT_ROOT / "models"
    DATA_DIR: Path = PROJECT_ROOT / "data"
    UPLOADS_DIR: Path = DATA_DIR / "uploads"
    OUTPUTS_DIR: Path = DATA_DIR / "outputs"

    # API 配置
    API_V1_PREFIX: str = "/api/v1"
    PROJECT_NAME: str = "Paper-Loom OCR"

    # 模型配置
    PADDLEOCR_MODELS: dict = {
        "small": "PP-OCRv4_mobile_en",
        "base": "PP-OCRv4_server_en"
    }

    # PDF处理配置
    PDF_DPI: int = 300
    MAX_FILE_SIZE: int = 50 * 1024 * 1024  # 50MB

    # 设备配置
    DEVICE: str = "cuda"  # cuda/cpu/mps

    class Config:
        case_sensitive = True
        env_file = ".env"


settings = Settings()

# 确保目录存在
settings.UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
settings.OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)