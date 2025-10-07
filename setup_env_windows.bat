@echo off
echo ====================================
echo Windows 环境配置 (CUDA 12.9)
echo ====================================

:: 激活 conda 环境
call conda activate paper-loom

:: 安装 PyTorch (CUDA 12.1)
echo 正在安装 PyTorch...
pip install torch==2.5.1 torchvision==0.20.1 --index-url https://download.pytorch.org/whl/cu121

:: 安装 PaddlePaddle GPU
echo 正在安装 PaddlePaddle GPU...
pip install paddlepaddle-gpu==3.0.0.post121 -f https://www.paddlepaddle.org.cn/whl/windows/mkl/avx/stable.html

:: 安装 FastAPI 等基础依赖
echo 正在安装 FastAPI...
pip install fastapi==0.115.5 uvicorn[standard]==0.32.1 python-multipart==0.0.20
pip install python-dotenv==1.0.1 aiofiles==24.1.0 loguru==0.7.3
pip install pydantic==2.10.3 pydantic-settings==2.7.0

:: 安装 OCR 和图像处理
echo 正在安装 OCR 组件...
pip install paddleocr==2.9.2
pip install pymupdf==1.25.3 Pillow==11.0.0 opencv-python==4.10.0.84
pip install numpy==1.26.4

:: 安装深度学习模型库
echo 正在安装深度学习组件...
pip install transformers==4.47.1
pip install ultralytics==8.3.50
pip install huggingface-hub==0.26.5

:: 安装 MinerU (包含 PDF-Extract-Kit 的功能)
echo 正在安装 MinerU...
pip install magic-pdf[full]==1.3.12

echo.
echo ✅ 环境配置完成！
echo.
echo 接下来：
echo 1. cd backend\app
echo 2. python main.py
echo.
pause