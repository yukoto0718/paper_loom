# Paper-Loom 前端清理指南

## 🎯 清理说明

如果你计划使用 Flutter 前端替代现有的 HTML/CSS/JS 前端，可以安全删除以下内容。

## 📁 可安全删除的文件和目录

### 1. 前端目录 (完全删除)
```
frontend/                    # 整个前端目录可以删除
├── index.html              # 主页面
├── assets/                 # 静态资源
├── css/                    # 样式文件
│   └── style.css
└── js/                     # JavaScript 文件
    └── app.js
```

### 2. 后端中仅用于前端展示的代码

**文件**: `backend/app/api/v1/ocr.py`

**可以删除的部分**:
```python
# 以下路由仅用于前端页面展示，可以删除
@router.get("/", response_class=HTMLResponse)
async def ocr_homepage():
    """OCR 主页 - 仅用于前端展示"""
    return """
    <html>
        <head><title>Paper-Loom OCR</title></head>
        <body>
            <h1>Paper-Loom OCR System</h1>
            <!-- 前端界面代码 -->
        </body>
    </html>
    """
```

### 3. 配置文件中前端相关设置

**文件**: `backend/app/core/config.py`

**可以删除的配置**:
```python
# 以下配置仅用于前端，可以删除或注释掉
FRONTEND_URL = "http://localhost:8000"  # 前端地址
CORS_ORIGINS = ["http://localhost:8000"]  # CORS 设置
```

## 🔧 清理后的配置调整

### 1. 更新 CORS 配置
在 `backend/app/main.py` 中更新 CORS 设置：

```python
# 清理前 (支持前端)
origins = [
    "http://localhost:8000",
    "http://127.0.0.1:8000",
]

# 清理后 (仅支持 Flutter 前端)
origins = [
    "http://localhost",      # Flutter web
    "http://127.0.0.1",     # Flutter web
    # 添加 Flutter 移动端的域名或 IP
]
```

### 2. 简化依赖
在 `backend/requirements.txt` 中，可以移除仅用于前端的依赖：

```txt
# 以下依赖可以移除（如果不再需要）
jinja2          # 模板渲染（如果只用于前端）
```

## 📋 清理步骤

### 步骤 1: 删除前端文件
```bash
# 删除整个前端目录
rm -rf frontend/
```

### 步骤 2: 清理后端代码
编辑 `backend/app/api/v1/ocr.py`，删除或注释掉前端相关的路由：

```python
# 删除这个路由
@router.get("/", response_class=HTMLResponse)
async def ocr_homepage():
    # 删除这个函数的所有内容
    pass
```

### 步骤 3: 更新配置
编辑 `backend/app/core/config.py`：

```python
# 注释掉或删除前端相关配置
# FRONTEND_URL = "http://localhost:8000"

# 更新为仅 API 模式
API_ONLY = True
```

### 步骤 4: 更新主应用
编辑 `backend/app/main.py`：

```python
# 移除前端静态文件服务
# app.mount("/static", StaticFiles(directory="frontend/assets"), name="static")

# 简化 CORS 配置
origins = [
    "http://localhost",      # Flutter web
    "http://127.0.0.1",     # Flutter web
    # 添加你的 Flutter 应用域名
]
```

## 🚀 清理后的项目结构

```
paper-loom-backend/
├── README.md                      # 项目说明
├── API_DOCUMENTATION.md          # API 文档
├── MINERU_IMPLEMENTATION_GUIDE.md # 技术文档
├── CLEANUP_GUIDE.md              # 本清理指南
├── backend/                      # 纯后端
│   ├── app/
│   │   ├── api/v1/ocr.py         # 仅保留 API 接口
│   │   ├── modules/ocr/          # OCR 处理模块
│   │   └── core/                 # 核心配置
│   ├── requirements.txt          # 后端依赖
│   └── install_mineru.py         # MinerU 安装
├── data/                         # 文件存储
│   ├── uploads/                  # 上传文件
│   └── outputs/                  # 处理结果
└── LICENSE                       # 许可证
```

## 🔗 Flutter 前端集成

清理后，你的 Flutter 应用可以通过以下方式集成：

### 1. 基础 URL
```
开发环境: http://localhost:8000
API 前缀: /api/v1
```

### 2. 核心接口
- `POST /api/v1/ocr/upload` - 文件上传
- `POST /api/v1/ocr/process` - 启动处理
- `GET /api/v1/ocr/status/{job_id}` - 状态查询
- `GET /api/v1/ocr/download/{job_id}` - 结果下载

### 3. 错误处理
所有接口返回统一格式的 JSON 响应，包含详细的错误信息。

## 📊 清理前后对比

| 项目 | 清理前 | 清理后 |
|------|--------|--------|
| **前端** | HTML/CSS/JS | Flutter 应用 |
| **后端角色** | 提供前端界面 + API | 纯 API 服务 |
| **项目大小** | 包含前端资源 | 更小更专注 |
| **维护复杂度** | 需要维护两套前端 | 只需维护 API |
| **部署** | 需要部署静态文件 | 仅部署 API 服务 |

## ⚠️ 注意事项

1. **备份重要文件**
   - 在删除前备份 `frontend/` 目录（如果需要）
   - 备份配置文件修改前的版本

2. **测试 API**
   - 清理后使用 Postman 或 curl 测试 API 是否正常工作
   - 确保 Flutter 前端可以正常调用

3. **文档更新**
   - 更新 README.md 中的前端说明
   - 确保 API_DOCUMENTATION.md 保持最新

4. **依赖清理**
   - 运行 `pip freeze` 检查是否有未使用的依赖
   - 更新 requirements.txt

## 🎯 推荐清理策略

### 渐进式清理
1. 先删除 `frontend/` 目录
2. 测试 API 是否正常工作
3. 逐步清理后端中的前端相关代码
4. 最后更新配置和文档

### 验证步骤
```bash
# 1. 启动后端服务
cd backend
python -m uvicorn app.main:app --reload

# 2. 测试 API
curl -X POST http://localhost:8000/api/v1/ocr/upload -F "file=@test.pdf"

# 3. 验证响应格式
# 应该返回 JSON 格式的响应，而不是 HTML
```

## 📞 技术支持

如果在清理过程中遇到问题：
1. 检查 API 文档确保接口调用正确
2. 查看后端日志获取详细错误信息
3. 恢复备份文件重新尝试

---

**清理完成后的 Paper-Loom** 将是一个纯粹的 API 后端服务，专门为 Flutter 前端提供 OCR 处理能力！ 🚀
