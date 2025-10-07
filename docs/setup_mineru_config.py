import json
from pathlib import Path

# 项目根目录
project_root = Path(__file__).parent.parent
models_dir = project_root / "models"

# 用户目录
user_home = Path.home()
config_file = user_home / "magic-pdf.json"

# MinerU 需要的配置
config = {
    "models-dir": str(models_dir.absolute()),
    "device-mode": "cuda",
    "table-config": {
        "model": "TableMaster",
        "enable": True
    },
    "formula-config": {
        "mfd_model": "yolo_v8_mfd",
        "mfr_model": "unimernet_small",
        "enable": True
    },
    "layout-config": {
        "model": "doclayout_yolo"
    }
}

# 写入配置
config_file.write_text(json.dumps(config, indent=2, ensure_ascii=False), encoding='utf-8')

print(f"✅ MinerU 配置已生成: {config_file}")
print(json.dumps(config, indent=2, ensure_ascii=False))