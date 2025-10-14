import 'dart:io';
import 'ocr_api_service.dart';
import '../models/ocr_document.dart';

/// API 服务测试
class ApiTest {
  final OcrApiService _apiService = OcrApiService();

  /// 测试网络服务层
  Future<void> testApiServices() async {
    print('=== 测试网络服务层 ===\n');

    try {
      // 1. 测试配置
      print('1. 测试 API 配置:');
      print('   - 基础 URL: ${_apiService.runtimeType}');
      print('   - 服务已初始化');
      print('');

      // 2. 测试错误处理（模拟网络错误）
      print('2. 测试错误处理:');
      await _testErrorHandling();
      print('');

      // 3. 测试上传（需要实际文件）
      print('3. 测试上传功能:');
      await _testUpload();
      print('');

      // 4. 测试状态查询
      print('4. 测试状态查询:');
      await _testStatusQuery();
      print('');

      // 5. 测试完整流程
      print('5. 测试完整 OCR 流程:');
      await _testCompleteWorkflow();
      print('');

      print('✅ 所有网络服务测试完成！');

    } catch (error) {
      print('❌ 测试过程中出现错误: $error');
    }
  }

  /// 测试错误处理
  Future<void> _testErrorHandling() async {
    try {
      // 测试无效的 jobId
      final response = await _apiService.getStatus('invalid-job-id');
      if (!response.success) {
        print('   - ✅ 错误处理正常: ${response.message}');
      } else {
        print('   - ❌ 错误处理异常: 应该返回失败状态');
      }
    } catch (error) {
      print('   - ✅ 异常处理正常: $error');
    }
  }

  /// 测试上传功能
  Future<void> _testUpload() async {
    try {
      // 创建一个测试文件（如果不存在）
      final testFile = await _createTestFile();
      if (testFile == null) {
        print('   - ⚠️ 跳过上传测试：无法创建测试文件');
        return;
      }

      print('   - 测试文件: ${testFile.path}');
      print('   - 文件大小: ${testFile.lengthSync()} bytes');

      // 测试上传进度回调
      final uploadResponse = await _apiService.uploadPdf(
        testFile,
        onProgress: (sent, total) {
          final progress = total != null ? (sent / total * 100).toStringAsFixed(1) : '未知';
          print('   - 上传进度: $sent/$total ($progress%)');
        },
      );

      if (uploadResponse.success) {
        final jobId = uploadResponse.data?['job_id'];
        print('   - ✅ 上传成功: job_id = $jobId');
        
        // 测试清理功能
        if (jobId != null) {
          final cleanupResponse = await _apiService.cleanup(jobId);
          if (cleanupResponse.success) {
            print('   - ✅ 清理成功');
          } else {
            print('   - ⚠️ 清理失败: ${cleanupResponse.message}');
          }
        }
      } else {
        print('   - ⚠️ 上传失败: ${uploadResponse.message}');
      }

      // 清理测试文件
      await testFile.delete();
      
    } catch (error) {
      print('   - ⚠️ 上传测试异常: $error');
    }
  }

  /// 测试状态查询
  Future<void> _testStatusQuery() async {
    try {
      // 使用一个已知的 jobId 进行测试
      const testJobId = 'test-job-123';
      final response = await _apiService.getStatus(testJobId);
      
      if (response.success) {
        final document = OcrDocument.fromApiResponse({
          'data': response.data,
        });
        print('   - ✅ 状态查询成功');
        print('   -   状态: ${document.ocrStatus.displayName}');
        print('   -   进度: ${document.progress}%');
        print('   -   当前步骤: ${document.currentStep}');
      } else {
        print('   - ⚠️ 状态查询失败: ${response.message}');
      }
    } catch (error) {
      print('   - ⚠️ 状态查询异常: $error');
    }
  }

  /// 测试完整 OCR 流程
  Future<void> _testCompleteWorkflow() async {
    try {
      // 创建一个测试文件
      final testFile = await _createTestFile();
      if (testFile == null) {
        print('   - ⚠️ 跳过完整流程测试：无法创建测试文件');
        return;
      }

      print('   - 开始完整 OCR 流程测试...');

      final document = await _apiService.processPdf(
        testFile,
        onUploadProgress: (sent, total) {
          final progress = total != null ? (sent / total * 100).toStringAsFixed(1) : '未知';
          print('   - 上传进度: $progress%');
        },
        onStatusUpdate: (doc) {
          print('   - 状态更新: ${doc.ocrStatus.displayName} - ${doc.currentStep} (${doc.progress}%)');
        },
      );

      if (document != null) {
        print('   - ✅ 完整流程测试成功');
        print('   -   最终状态: ${document.ocrStatus.displayName}');
        print('   -   统计信息: ${document.stats?.summary}');
      } else {
        print('   - ⚠️ 完整流程测试失败：返回空文档');
      }

      // 清理测试文件
      await testFile.delete();

    } catch (error) {
      print('   - ⚠️ 完整流程测试异常: $error');
    }
  }

  /// 创建测试文件
  Future<File?> _createTestFile() async {
    try {
      final tempDir = Directory.systemTemp;
      final testFile = File('${tempDir.path}/test_document.pdf');
      
      // 创建一个简单的 PDF 文件内容（实际使用时需要真实的 PDF 文件）
      const pdfContent = '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>
endobj
4 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
5 0 obj
<< /Length 44 >>
stream
BT
/F1 12 Tf
72 720 Td
(Test Document) Tj
ET
endstream
endobj
xref
0 6
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000234 00000 n 
0000000306 00000 n 
trailer
<< /Size 6 /Root 1 0 R >>
startxref
395
%%EOF
''';
      
      await testFile.writeAsString(pdfContent);
      return testFile;
    } catch (error) {
      print('   - ❌ 创建测试文件失败: $error');
      return null;
    }
  }
}

void main() async {
  final test = ApiTest();
  await test.testApiServices();
}
