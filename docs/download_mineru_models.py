import os
import sys
from pathlib import Path
from huggingface_hub import snapshot_download

# 设置模型路径
project_root = Path(__file__).parent.parent
models_dir = project_root / "models"
models_dir.mkdir(exist_ok=True)

os.environ['MINERU_MODEL_PATH'] = str(models_dir)

print("=" * 60)
print("开始下载 MinerU 模型（仅英文 + small/base）")
print(f"目标目录: {models_dir}")
print("=" * 60)

try:
    # 下载 PDF-Extract-Kit（仅英文模型）
    print("\n下载 PDF-Extract-Kit（仅英文 OCR）...")
    snapshot_download(
        repo_id="opendatalab/PDF-Extract-Kit-1.0",
        local_dir=str(models_dir / "PDF-Extract-Kit"),
        allow_patterns=[
            # === 仅英文 OCR ===
            "models/OCR/paddleocr_torch/en_PP-OCRv3_*",
            "models/OCR/paddleocr_torch/en_PP-OCRv4_*",
            "models/OCR/paddleocr_torch/en_PP-OCRv5_*",

            # === 检测模型（必需）===
            "models/Layout/**",
            "models/OCR/PaddleOCR/det/**",

            # === 公式检测/识别（仅 small + base）===
            "models/MFD/**",
            "models/MFR/unimernet_small/**",
            "models/MFR/unimernet_base/**",

            # === 配置文件 ===
            "*.yaml",
            "*.json",
            "*.txt",
            "README.md",
        ],
        ignore_patterns=[
            # 排除所有非英文语言
            "*chinese*",
            "*cht*",
            "*arabic*",
            "*cyrillic*",
            "*devanagari*",
            "*japan*",
            "*ka_*",
            "*eslav*",
            "*el_*",

            # 排除非 small/base 版本
            "*tiny*",
            "*large*",
            "*2501*",
            "*2503*",
        ],
        max_workers=8,
        resume_download=True
    )

    print("✅ 所有模型下载完成！")
    print("\n已下载的模型:")
    print("  ✅ 英文 OCR (PP-OCRv3/v4/v5)")
    print("  ✅ 布局检测 (Layout)")
    print("  ✅ 公式检测 (MFD)")
    print("  ✅ 公式识别 (unimernet_small + base)")

    # 显示目录结构
    print("\n目录结构:")
    for root, dirs, files in os.walk(models_dir):
        level = root.replace(str(models_dir), '').count(os.sep)
        if level < 3:  # 只显示前3层
            indent = '  ' * level
            print(f"{indent}{os.path.basename(root)}/")

except Exception as e:
    print(f"❌ 下载失败: {e}")
    sys.exit(1)