import json
from pathlib import Path
import platform
import torch

# 项目根目录
project_root = Path(__file__).parent.parent
models_dir = project_root / "models"

# 用户目录
user_home = Path.home()
config_file = user_home / "magic-pdf.json"

# 智能检测设备
def get_device_mode():
    system = platform.system()
    
    if system == "Windows":
        return "cuda"
    elif system == "Darwin":  # macOS
        # 检测是否为 Apple Silicon
        machine = platform.machine()
        if machine == "arm64":  # M1/M2/M3 芯片
            # 检查 MPS 是否可用
            if torch.backends.mps.is_available():
                print("🍎 检测到 Apple Silicon (M1/M2/M3)")
                print("✅ MPS 加速可用")
                return "mps"  # 尝试使用 MPS
            else:
                print("⚠️ MPS 不可用，使用 CPU")
                return "cpu"
        else:
            return "cpu"
    else:
        return "cpu"

device_mode = get_device_mode()

# MinerU 配置
config = {
    "models-dir": str(models_dir.absolute()),
    "device-mode": device_mode,
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
print(f"📱 系统: {platform.system()} ({platform.machine()})")
print(f"🚀 设备模式: {device_mode}")
print("\n配置内容:")
print(json.dumps(config, indent=2, ensure_ascii=False))