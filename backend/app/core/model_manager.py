import torch
from loguru import logger
from .config import settings
import subprocess


class ModelManager:
    def __init__(self):
        self.models_dir = settings.MODELS_DIR
        self.device = self._get_device()

    def _get_device(self) -> str:
        """自动检测设备"""
        if torch.cuda.is_available():
            return "cuda"
        elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            return "mps"
        else:
            return "cpu"

    async def download_models_if_needed(self):
        """
        检查 MinerU 是否正确安装
        """
        logger.info("检查 MinerU 安装...")

        try:
            # 检查命令行工具 - 修复编码问题
            result = subprocess.run(
                ["magic-pdf", "--version"],
                capture_output=True,
                text=True,
                encoding='utf-8',
                errors='ignore',
                timeout=10
            )

            if result.returncode == 0:
                logger.info("✅ MinerU 已正确安装")
                logger.info(f"   版本: {result.stdout.strip()}")
                logger.info(f"   设备: {self.device}")
            else:
                logger.warning("⚠️ MinerU 安装可能有问题")
                logger.warning("   请运行: pip install magic-pdf[full] --extra-index-url https://wheels.myhloli.com")

        except FileNotFoundError:
            logger.error("❌ 未找到 magic-pdf 命令")
            logger.error("   请运行: pip install magic-pdf[full] --extra-index-url https://wheels.myhloli.com")
            raise RuntimeError("MinerU 未安装")
        except Exception as e:
            logger.error(f"❌ MinerU 检查失败: {e}")
            raise


# 全局实例
model_manager = ModelManager()
