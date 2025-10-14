import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

class FileStorageService {
  /// 获取 OCR 文档存储目录
  static Future<Directory> getOcrDocumentsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final ocrDir = Directory('${appDir.path}/ocr_documents');
    
    if (!await ocrDir.exists()) {
      await ocrDir.create(recursive: true);
    }
    
    return ocrDir;
  }

  /// 获取特定 job 的目录
  static Future<Directory> getJobDirectory(String jobId) async {
    final ocrDir = await getOcrDocumentsDirectory();
    final jobDir = Directory('${ocrDir.path}/$jobId');
    
    if (!await jobDir.exists()) {
      await jobDir.create(recursive: true);
    }
    
    return jobDir;
  }

  /// 解压 ZIP 文件到指定目录
  static Future<Map<String, String>> extractZip(
    String zipPath,
    String targetDir,
  ) async {
    try {
      // 读取 ZIP 文件
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 解压文件
      for (final file in archive) {
        final filename = file.name;
        final filePath = path.join(targetDir, filename);

        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filePath).create(recursive: true);
        }
      }

      // 返回关键文件路径
      return {
        'markdown': path.join(targetDir, 'output.md'),
        'images': path.join(targetDir, 'images'),
        'metadata': path.join(targetDir, 'metadata.json'),
      };
    } catch (e) {
      print('解压 ZIP 失败: $e');
      rethrow;
    }
  }

  /// 删除 job 目录及其所有内容
  static Future<void> deleteJobDirectory(String jobId) async {
    try {
      final jobDir = await getJobDirectory(jobId);
      if (await jobDir.exists()) {
        await jobDir.delete(recursive: true);
      }
    } catch (e) {
      print('删除目录失败: $e');
    }
  }

  /// 获取目录大小
  static Future<int> getDirectorySize(Directory dir) async {
    int totalSize = 0;
    
    await for (var entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    
    return totalSize;
  }
}
