#!/usr/bin/env python3
"""
MinerU 安装脚本
确保 MinerU 正确安装并配置
"""

import subprocess
import sys
import os
from pathlib import Path

def run_command(cmd, description):
    """运行命令并检查结果"""
    print(f"🔧 {description}...")
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✅ {description} 成功")
            return True
        else:
            print(f"❌ {description} 失败")
            print(f"错误信息: {result.stderr}")
            return False
    except Exception as e:
        print(f"❌ {description} 异常: {e}")
        return False

def main():
    print("🚀 开始安装 MinerU...")
    
    # 1. 安装 MinerU
    if not run_command(
        f'"{sys.executable}" -m pip install -U mineru[core]',
        "安装 MinerU[core]"
    ):
        print("❌ MinerU 安装失败，请手动安装: pip install -U mineru[core]")
        return False
    
    # 2. 验证安装
    print("🔍 验证 MinerU 安装...")
    
    # 检查 Python 导入
    try:
        import mineru
        print("✅ MinerU Python API 导入成功")
    except ImportError as e:
        print(f"❌ MinerU Python API 导入失败: {e}")
        return False
    
    # 检查 CLI
    try:
        result = subprocess.run(
            ["mineru", "--version"],
            capture_output=True,
            text=True,
            timeout=10
        )
        if result.returncode == 0:
            print(f"✅ MinerU CLI 可用: {result.stdout.strip()}")
        else:
            print(f"⚠️ MinerU CLI 不可用: {result.stderr}")
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        print(f"⚠️ MinerU CLI 检查失败: {e}")
    
    print("\n🎉 MinerU 安装完成！")
    print("📝 下一步:")
    print("1. 重启 FastAPI 服务器以应用新安装的包")
    print("2. 测试 PDF 转换功能")
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
