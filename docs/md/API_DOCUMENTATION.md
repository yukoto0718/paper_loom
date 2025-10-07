# Paper-Loom API 文档

## 🎯 后端接口说明

本文档为 Flutter 前端开发提供完整的后端 API 接口信息，便于前后端联调。

## 📋 基础信息

### 服务器地址
```
开发环境: http://localhost:8000
生产环境: [根据部署环境配置]
```

### API 前缀
```
/api/v1
```

### 响应格式
所有接口返回 JSON 格式数据：
```json
{
  "success": true,
  "message": "操作成功",
  "data": {...},
  "error": null
}
```

## 🔄 OCR 处理流程

### 完整处理流程
```
1. 上传PDF文件 → 2. 启动处理任务 → 3. 轮询处理状态 → 4. 下载结果
```

## 📤 文件上传接口

### POST `/api/v1/ocr/upload`

**功能**: 上传 PDF 文件

**请求头**:
```
Content-Type: multipart/form-data
```

**请求参数**:
- `file`: PDF 文件 (multipart/form-data)

**成功响应**:
```json
{
  "success": true,
  "message": "文件上传成功",
  "data": {
    "job_id": "8bc053f2-54bd-4821-8c6c-8eba4c9ecec7",
    "filename": "research_paper.pdf",
    "file_size": 2456789,
    "upload_time": "2025-10-07T14:22:32.433Z"
  },
  "error": null
}
```

**错误响应**:
```json
{
  "success": false,
  "message": "文件上传失败",
  "data": null,
  "error": {
    "code": "FILE_UPLOAD_ERROR",
    "details": "文件大小超过限制"
  }
}
```

## ⚙️ 处理任务接口

### POST `/api/v1/ocr/process`

**功能**: 启动 OCR 处理任务

**请求头**:
```
Content-Type: application/json
```

**请求体**:
```json
{
  "job_id": "8bc053f2-54bd-4821-8c6c-8eba4c9ecec7"
}
```

**成功响应**:
```json
{
  "success": true,
  "message": "处理任务已启动",
  "data": {
    "job_id": "8bc053f2-54bd-4821-8c6c-8eba4c9ecec7",
    "status": "processing",
    "started_at": "2025-10-07T14:22:33.225Z",
    "estimated_time": 120
  },
  "error": null
}
```

## 📊 状态查询接口

### GET `/api/v1/ocr/status/{job_id}`

**功能**: 查询处理任务状态

**路径参数**:
- `job_id`: 任务ID

**成功响应**:
```json
{
  "success": true,
  "message": "状态查询成功",
  "data": {
    "job_id": "8bc053f2-54bd-4821-8c6c-8eba4c9ecec7",
    "status": "completed", // processing, completed, failed
    "progress": 100,
    "current_step": "生成Markdown",
    "started_at": "2025-10-07T14:22:33.225Z",
    "completed_at": "2025-10-07T14:23:15.424Z",
    "elapsed_time": 42,
    "stats": {
      "total_pages": 12,
      "total_images": 8,
      "tables": 3,
      "formulas": 15,
      "total_elements": 156
    }
  },
  "error": null
}
```

**状态说明**:
- `uploaded`: 文件已上传
- `processing`: 处理中
- `completed`: 处理完成
- `failed`: 处理失败

## 📥 结果下载接口

### GET `/api/v1/ocr/download/{job_id}`

**功能**: 下载处理结果

**路径参数**:
- `job_id`: 任务ID

**成功响应**:
返回 ZIP 文件，包含：
- `output.md`: 生成的 Markdown 文件
- `images/`: 图片目录
- `metadata.json`: 元数据文件

**响应头**:
```
Content-Type: application/zip
Content-Disposition: attachment; filename="result_8bc053f2-54bd-4821-8c6c-8eba4c9ecec7.zip"
```

**元数据文件内容**:
```json
{
  "job_id": "8bc053f2-54bd-4821-8c6c-8eba4c9ecec7",
  "filename": "research_paper.pdf",
  "processed_at": "2025-10-07T14:23:15.424Z",
  "processing_time": 42,
  "stats": {
    "total_pages": 12,
    "total_images": 8,
    "tables": 3,
    "formulas": 15,
    "total_elements": 156
  },
  "mineru_success": true,
  "fallback_used": false
}
```

## 🗑️ 清理接口

### DELETE `/api/v1/ocr/cleanup/{job_id}`

**功能**: 清理任务相关文件

**路径参数**:
- `job_id`: 任务ID

**成功响应**:
```json
{
  "success": true,
  "message": "文件清理完成",
  "data": {
    "job_id": "8bc053f2-54bd-4821-8c6c-8eba4c9ecec7",
    "cleaned_files": ["uploaded_pdf", "output_markdown", "images"]
  },
  "error": null
}
```

## ⚠️ 错误码说明

| 错误码 | 说明 | HTTP 状态码 |
|--------|------|-------------|
| `FILE_UPLOAD_ERROR` | 文件上传失败 | 400 |
| `FILE_TOO_LARGE` | 文件大小超过限制 | 413 |
| `INVALID_FILE_TYPE` | 不支持的文件类型 | 400 |
| `JOB_NOT_FOUND` | 任务不存在 | 404 |
| `PROCESSING_FAILED` | 处理失败 | 500 |
| `PROCESSING_TIMEOUT` | 处理超时 | 408 |

## 🔧 后端处理逻辑

### 处理流程详解

1. **文件验证**
   - 检查文件类型 (仅支持 PDF)
   - 检查文件大小 (最大 50MB)
   - 生成唯一 job_id

2. **MinerU 处理**
   - 使用 GPU 加速 (RTX 4060)
   - 布局分析和文本识别
   - 图片提取和定位
   - 公式识别为 LaTeX

3. **结果整理**
   - 生成结构化 Markdown
   - 整理图片文件
   - 生成统计信息

### 超时机制
- 处理超时: 5分钟
- 自动启用备用方案

### 备用处理方案
当 MinerU 处理失败时，自动使用 PyPDF2 进行基本文本提取。

## 📱 Flutter 前端集成示例

### 文件上传示例
```dart
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> uploadPdf(File pdfFile) async {
  var request = http.MultipartRequest(
    'POST',
    Uri.parse('http://localhost:8000/api/v1/ocr/upload'),
  );
  
  request.files.add(await http.MultipartFile.fromPath(
    'file',
    pdfFile.path,
  ));
  
  var response = await request.send();
  var responseData = await response.stream.bytesToString();
  return json.decode(responseData);
}
```

### 状态轮询示例
```dart
Future<Map<String, dynamic>> pollStatus(String jobId) async {
  var response = await http.get(
    Uri.parse('http://localhost:8000/api/v1/ocr/status/$jobId'),
  );
  
  if (response.statusCode == 200) {
    var data = json.decode(response.body);
    
    if (data['data']['status'] == 'processing') {
      // 继续轮询
      await Future.delayed(Duration(seconds: 2));
      return await pollStatus(jobId);
    }
    
    return data;
  } else {
    throw Exception('状态查询失败');
  }
}
```

### 文件下载示例
```dart
Future<void> downloadResult(String jobId) async {
  var response = await http.get(
    Uri.parse('http://localhost:8000/api/v1/ocr/download/$jobId'),
  );
  
  if (response.statusCode == 200) {
    // 保存 ZIP 文件
    var zipData = response.bodyBytes;
    // ... 文件保存逻辑
  } else {
    throw Exception('下载失败');
  }
}
```

## 🎯 前端开发建议

### 1. 用户体验优化
- 显示实时处理进度
- 提供取消处理功能
- 显示详细的错误信息
- 支持断点续传

### 2. 错误处理
- 网络连接失败重试
- 文件上传进度显示
- 处理超时提示
- 备用方案自动启用

### 3. 性能优化
- 使用分块上传大文件
- 实现后台处理状态查询
- 缓存处理结果
- 支持批量处理

## 🔄 完整工作流示例

```dart
class OcrService {
  static Future<OcrResult> processPdf(File pdfFile) async {
    try {
      // 1. 上传文件
      var uploadResult = await uploadPdf(pdfFile);
      String jobId = uploadResult['data']['job_id'];
      
      // 2. 启动处理
      await startProcessing(jobId);
      
      // 3. 轮询状态
      var statusResult = await pollStatus(jobId);
      
      // 4. 下载结果
      var downloadResult = await downloadResult(jobId);
      
      return OcrResult(
        success: true,
        markdown: downloadResult.markdown,
        images: downloadResult.images,
        stats: statusResult['data']['stats'],
      );
    } catch (e) {
      return OcrResult(
        success: false,
        error: e.toString(),
      );
    }
  }
}
```

## 📞 技术支持

如有接口问题，请检查：
1. 服务器是否正常运行
2. 网络连接是否正常
3. 文件格式和大小是否符合要求
4. 查看后端日志获取详细错误信息

---

**Paper-Loom API** - 为 Flutter 前端提供完整的 OCR 处理能力！ 🚀
