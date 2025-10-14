import 'dart:io';
import 'package:dio/dio.dart';
import 'base_api_service.dart';
import 'api_config.dart';
import '../models/api_response.dart';
import '../models/ocr_document.dart';

/// OCR API 服务类
/// 
/// 实现与后端 OCR 相关的所有 API 调用
class OcrApiService {
  final BaseApiService _apiService;

  OcrApiService() : _apiService = BaseApiService();

  /// 上传 PDF 文件
  /// 
  /// [pdfFile] - 要上传的 PDF 文件
  /// [onProgress] - 上传进度回调
  /// 
  /// 返回包含 job_id 的响应
  Future<ApiResponse<Map<String, dynamic>>> uploadPdf(
    File pdfFile, {
    ProgressCallback? onProgress,
  }) async {
    return await _apiService.upload<Map<String, dynamic>>(
      ApiEndpoints.getUploadUrl(),
      file: pdfFile,
      fieldName: 'file',
      onProgress: onProgress,
      dataParser: (data) => data,
    );
  }

  /// 启动 OCR 处理
  /// 
  /// [jobId] - 任务 ID
  /// [ocrModel] - OCR 模型类型（small/base）
  /// 
  /// 返回处理状态响应
  Future<ApiResponse<Map<String, dynamic>>> startProcessing(
    String jobId, {
    String ocrModel = 'small',
  }) async {
    try {
      print('🔧 [API] 调用 startProcessing, jobId: $jobId');
      print('🔧 [API] 请求 URL: ${ApiEndpoints.getStartProcessingUrl()}');
      print('🔧 [API] 请求数据: {"job_id": "$jobId", "ocr_model": "$ocrModel"}');
      
      final response = await _apiService.post<Map<String, dynamic>>(
        ApiEndpoints.getStartProcessingUrl(),
        data: {
          'job_id': jobId,
          'ocr_model': ocrModel,
        },
        dataParser: (data) => data,
      );
      
      print('🔧 [API] startProcessing 响应: ${response.success}');
      print('🔧 [API] 响应消息: ${response.message}');
      print('🔧 [API] 响应数据: ${response.data}');
      
      return response;
      
    } catch (e) {
      print('❌ [API] startProcessing 错误: $e');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: '启动处理失败: $e',
        data: null,
      );
    }
  }

  /// 查询处理状态
  /// 
  /// [jobId] - 任务 ID
  /// 
  /// 返回包含处理状态和进度的响应
  Future<ApiResponse<Map<String, dynamic>>> getStatus(String jobId) async {
    return await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.getStatusUrl(jobId),
      dataParser: (data) => data,
    );
  }

  /// 下载 Markdown 结果文件
  /// 
  /// [jobId] - 任务 ID
  /// [savePath] - 保存路径
  /// [onProgress] - 下载进度回调
  /// 
  /// 返回下载文件的本地路径
  Future<String> downloadMarkdown(
    String jobId,
    String savePath, {
    ProgressCallback? onProgress,
  }) async {
    return await _apiService.download(
      ApiEndpoints.getDownloadUrl(jobId),
      savePath,
      onProgress: onProgress,
    );
  }

  /// 下载 ZIP 结果包（包含 Markdown 和图片）
  /// 
  /// [jobId] - 任务 ID
  /// [savePath] - 保存路径
  /// [onProgress] - 下载进度回调
  /// 
  /// 返回下载文件的本地路径
  Future<String> downloadZip(
    String jobId,
    String savePath, {
    ProgressCallback? onProgress,
  }) async {
    return await _apiService.download(
      ApiEndpoints.getDownloadZipUrl(jobId),
      savePath,
      onProgress: onProgress,
    );
  }

  /// 清理服务器文件
  /// 
  /// [jobId] - 任务 ID
  /// 
  /// 返回清理结果
  Future<ApiResponse<void>> cleanup(String jobId) async {
    return await _apiService.post<void>(
      ApiEndpoints.getCleanupUrl(jobId),
      dataParser: (data) => null,
    );
  }

  /// 完整的 OCR 处理流程
  /// 
  /// 封装上传、处理和下载的完整流程
  /// 
  /// [pdfFile] - 要处理的 PDF 文件
  /// [onUploadProgress] - 上传进度回调
  /// [onDownloadProgress] - 下载进度回调
  /// [onStatusUpdate] - 状态更新回调
  /// 
  /// 返回处理完成的 OcrDocument 对象
  Future<OcrDocument?> processPdf(
    File pdfFile, {
    ProgressCallback? onUploadProgress,
    ProgressCallback? onDownloadProgress,
    Function(OcrDocument)? onStatusUpdate,
  }) async {
    try {
      // 1. 上传 PDF
      final uploadResponse = await uploadPdf(
        pdfFile,
        onProgress: onUploadProgress,
      );

      if (!uploadResponse.success) {
        throw Exception('上传失败: ${uploadResponse.message}');
      }

      final jobId = uploadResponse.data?['job_id'] as String?;
      if (jobId == null) {
        throw Exception('无法获取任务 ID');
      }

      // 创建初始文档对象
      var document = OcrDocument.fromApiResponse({
        'data': uploadResponse.data,
      });

      // 通知状态更新
      onStatusUpdate?.call(document);

      // 2. 启动处理
      final processResponse = await startProcessing(jobId);
      if (!processResponse.success) {
        throw Exception('启动处理失败: ${processResponse.message}');
      }

      // 3. 轮询查询状态
      OcrDocument? finalDocument;
      bool isCompleted = false;

      while (!isCompleted) {
        // 等待一段时间再查询状态
        await Future.delayed(const Duration(seconds: 2));

        final statusResponse = await getStatus(jobId);
        if (!statusResponse.success) {
          throw Exception('查询状态失败: ${statusResponse.message}');
        }

        // 更新文档状态
        document = OcrDocument.fromApiResponse({
          'data': statusResponse.data,
        });

        // 通知状态更新
        onStatusUpdate?.call(document);

        // 检查是否完成
        if (document.isCompleted) {
          finalDocument = document;
          isCompleted = true;
        } else if (document.isFailed) {
          throw Exception('处理失败: ${document.errorMessage}');
        }
      }

      return finalDocument;

    } catch (error) {
      rethrow;
    }
  }

  /// 轮询查询状态直到完成
  /// 
  /// [jobId] - 任务 ID
  /// [onStatusUpdate] - 状态更新回调
  /// [pollInterval] - 轮询间隔（秒）
  /// [maxPollingTime] - 最大轮询时间（秒）
  /// 
  /// 返回处理完成的 OcrDocument 对象
  Future<OcrDocument> pollUntilCompleted(
    String jobId, {
    Function(OcrDocument)? onStatusUpdate,
    int pollInterval = 2,
    int maxPollingTime = 300, // 5分钟
  }) async {
    final startTime = DateTime.now();

    while (true) {
      // 检查是否超时
      final elapsedTime = DateTime.now().difference(startTime).inSeconds;
      if (elapsedTime > maxPollingTime) {
        throw Exception('处理超时，请稍后重试');
      }

      // 查询状态
      final statusResponse = await getStatus(jobId);
      if (!statusResponse.success) {
        throw Exception('查询状态失败: ${statusResponse.message}');
      }

      final document = OcrDocument.fromApiResponse({
        'data': statusResponse.data,
      });

      // 通知状态更新
      onStatusUpdate?.call(document);

      // 检查是否完成
      if (document.isCompleted) {
        return document;
      } else if (document.isFailed) {
        throw Exception('处理失败: ${document.errorMessage}');
      }

      // 等待下一次轮询
      await Future.delayed(Duration(seconds: pollInterval));
    }
  }

  /// 批量下载处理结果
  /// 
  /// [documents] - 要下载的文档列表
  /// [downloadDirectory] - 下载目录
  /// [onProgress] - 整体进度回调
  /// [onDocumentProgress] - 单个文档进度回调
  /// 
  /// 返回下载完成的文档列表
  Future<List<OcrDocument>> batchDownloadResults(
    List<OcrDocument> documents,
    String downloadDirectory, {
    ProgressCallback? onProgress,
    Function(OcrDocument, int, int)? onDocumentProgress,
  }) async {
    final results = <OcrDocument>[];
    final total = documents.length;

    for (int i = 0; i < total; i++) {
      final document = documents[i];
      
      if (onProgress != null) {
        onProgress(i, total);
      }

      try {
        // 为每个文档创建下载路径
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final zipPath = '$downloadDirectory/${document.jobId}_$timestamp.zip';

        // 下载 ZIP 包
        await downloadZip(
          document.jobId,
          zipPath,
          onProgress: (received, total) {
            onDocumentProgress?.call(document, received, total ?? 0);
          },
        );

        // 更新文档的本地文件路径
        final updatedDocument = document.copyWith(
          pdfFilePath: '$downloadDirectory/${document.jobId}.pdf',
          markdownFilePath: '$downloadDirectory/${document.jobId}/output.md',
          imagesDirectoryPath: '$downloadDirectory/${document.jobId}/images',
          metadataFilePath: '$downloadDirectory/${document.jobId}/metadata.json',
        );

        results.add(updatedDocument);

      } catch (error) {
        // 记录下载失败，但继续处理其他文档
        print('下载失败 ${document.jobId}: $error');
      }
    }

    return results;
  }
}
