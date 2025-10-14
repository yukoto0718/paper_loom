import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_document.dart';
import 'permission_service.dart';

/// PDF服务异常类
class PDFServiceException implements Exception {
  final String message;
  final String? details;
  
  const PDFServiceException(this.message, [this.details]);
  
  @override
  String toString() {
    return details != null ? '$message: $details' : message;
  }
}

/// PDF文件服务
/// 
/// 负责PDF文件的选择、管理、阅读进度保存等功能
class PDFService {
  static const String _recentFilesKey = 'recent_pdf_files';
  static const String _favoritesKey = 'favorite_pdf_files';
  static const String _readingProgressKey = 'reading_progress_';
  static const int _maxRecentFiles = 20;

  /// 选择PDF文件
  /// 
  /// 返回选中的PDF文件路径，如果用户取消选择则返回null
  static Future<String?> pickPDFFile() async {
    try {
      // 在Android上检查权限
      if (Platform.isAndroid) {
        final hasPermission = await PermissionService.hasStoragePermissions();
        if (!hasPermission) {
          final granted = await PermissionService.requestStoragePermissions();
          if (!granted) {
            throw const PDFServiceException('需要存储权限来选择PDF文件');
          }
        }
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        
        // 验证文件是否存在
        final file = File(filePath);
        if (!await file.exists()) {
          throw const PDFServiceException('所选文件不存在');
        }

        // 验证文件大小（限制为100MB）
        final fileSize = await file.length();
        if (fileSize > 100 * 1024 * 1024) {
          throw const PDFServiceException('文件太大，请选择小于100MB的PDF文件');
        }

        return filePath;
      }
      
      return null; // 用户取消选择
    } catch (e) {
      if (e is PDFServiceException) {
        rethrow;
      }
      throw PDFServiceException('选择文件时发生错误', e.toString());
    }
  }

  /// 创建PDF文档对象
  /// 
  /// [filePath] PDF文件路径
  /// 返回PDFDocument对象
  static Future<PDFDocument> createPDFDocument(String filePath) async {
    try {
      final file = File(filePath);
      
      // 检查文件是否存在
      if (!await file.exists()) {
        throw const PDFServiceException('PDF文件不存在');
      }

      // 获取文件信息
      final fileName = file.path.split('/').last;
      final fileSize = await file.length();
      
      // 获取PDF页数（这里使用flutter_pdfview获取）
      int totalPages = 1;
      try {
        // 创建一个临时的PDFViewController来获取页数
        // 注意：这种方式在实际使用中可能需要在Widget中获取
        totalPages = await _getPDFPageCount(filePath);
      } catch (e) {
        // 如果无法获取页数，默认为1
        totalPages = 1;
      }

      // 创建PDF文档对象
      final pdfDocument = PDFDocument(
        filePath: filePath,
        fileName: fileName,
        fileSize: fileSize,
        totalPages: totalPages,
      );

      // 加载保存的阅读进度
      await _loadReadingProgress(pdfDocument);
      
      // 添加到最近文件列表
      await _addToRecentFiles(pdfDocument);

      return pdfDocument;
    } catch (e) {
      if (e is PDFServiceException) {
        rethrow;
      }
      throw PDFServiceException('创建PDF文档时发生错误', e.toString());
    }
  }

  /// 获取PDF页数（辅助方法）
  static Future<int> _getPDFPageCount(String filePath) async {
    try {
      // 这里返回默认值，实际页数将在PDFView加载后获取
      return 1;
    } catch (e) {
      return 1;
    }
  }

  /// 保存阅读进度
  /// 
  /// [document] PDF文档对象
  static Future<void> saveReadingProgress(PDFDocument document) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressKey = _readingProgressKey + document.filePath.hashCode.toString();
      
      await prefs.setString(progressKey, jsonEncode(document.toJson()));
    } catch (e) {
      throw PDFServiceException('保存阅读进度时发生错误', e.toString());
    }
  }

  /// 加载阅读进度
  /// 
  /// [document] PDF文档对象
  static Future<void> _loadReadingProgress(PDFDocument document) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressKey = _readingProgressKey + document.filePath.hashCode.toString();
      
      final progressJson = prefs.getString(progressKey);
      if (progressJson != null) {
        final progressData = jsonDecode(progressJson) as Map<String, dynamic>;
        
        // 更新文档的阅读进度
        document.currentPage = progressData['currentPage'] as int? ?? 1;
        document.zoomLevel = (progressData['zoomLevel'] as num?)?.toDouble() ?? 1.0;
        document.isFavorite = progressData['isFavorite'] as bool? ?? false;
        
        if (progressData['lastReadTime'] != null) {
          document.lastReadTime = DateTime.parse(progressData['lastReadTime'] as String);
        }
        
        if (progressData['bookmarks'] != null) {
          document.bookmarks.clear();
          document.bookmarks.addAll(
            (progressData['bookmarks'] as List<dynamic>)
                .map((e) => e as int)
                .toList(),
          );
        }
      }
    } catch (e) {
      // 如果加载进度失败，使用默认值，不抛出异常
      debugPrint('加载阅读进度失败: $e');
    }
  }

  /// 获取最近阅读的文件列表
  static Future<List<PDFDocument>> getRecentFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentFilesJson = prefs.getString(_recentFilesKey);
      
      if (recentFilesJson == null) {
        return [];
      }

      final recentFilesList = jsonDecode(recentFilesJson) as List<dynamic>;
      final recentFiles = <PDFDocument>[];

      for (final fileData in recentFilesList) {
        try {
          final document = PDFDocument.fromJson(fileData as Map<String, dynamic>);
          
          // 检查文件是否仍然存在
          final file = File(document.filePath);
          if (await file.exists()) {
            recentFiles.add(document);
          }
        } catch (e) {
          // 跳过无效的文件记录
          debugPrint('跳过无效的文件记录: $e');
        }
      }

      return recentFiles;
    } catch (e) {
      throw PDFServiceException('获取最近文件列表时发生错误', e.toString());
    }
  }

  /// 添加文件到最近文件列表
  static Future<void> _addToRecentFiles(PDFDocument document) async {
    try {
      final recentFiles = await getRecentFiles();
      
      // 移除重复的文件
      recentFiles.removeWhere((file) => file.filePath == document.filePath);
      
      // 添加到列表开头
      recentFiles.insert(0, document);
      
      // 限制最大数量
      if (recentFiles.length > _maxRecentFiles) {
        recentFiles.removeRange(_maxRecentFiles, recentFiles.length);
      }
      
      // 保存到SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final recentFilesJson = jsonEncode(
        recentFiles.map((file) => file.toJson()).toList(),
      );
      
      await prefs.setString(_recentFilesKey, recentFilesJson);
    } catch (e) {
      throw PDFServiceException('添加到最近文件列表时发生错误', e.toString());
    }
  }

  /// 移除最近文件
  static Future<void> removeFromRecentFiles(String filePath) async {
    try {
      final recentFiles = await getRecentFiles();
      recentFiles.removeWhere((file) => file.filePath == filePath);
      
      final prefs = await SharedPreferences.getInstance();
      final recentFilesJson = jsonEncode(
        recentFiles.map((file) => file.toJson()).toList(),
      );
      
      await prefs.setString(_recentFilesKey, recentFilesJson);
    } catch (e) {
      throw PDFServiceException('移除最近文件时发生错误', e.toString());
    }
  }

  /// 获取收藏的文件列表
  static Future<List<PDFDocument>> getFavoriteFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getString(_favoritesKey);
      
      if (favoritesJson == null) {
        return [];
      }

      final favoritesList = jsonDecode(favoritesJson) as List<dynamic>;
      final favoriteFiles = <PDFDocument>[];

      for (final fileData in favoritesList) {
        try {
          final document = PDFDocument.fromJson(fileData as Map<String, dynamic>);
          
          // 检查文件是否仍然存在
          final file = File(document.filePath);
          if (await file.exists()) {
            favoriteFiles.add(document);
          }
        } catch (e) {
          // 跳过无效的文件记录
          debugPrint('跳过无效的收藏文件记录: $e');
        }
      }

      return favoriteFiles;
    } catch (e) {
      throw PDFServiceException('获取收藏文件列表时发生错误', e.toString());
    }
  }

  /// 切换收藏状态
  static Future<void> toggleFavorite(PDFDocument document) async {
    try {
      document.isFavorite = !document.isFavorite;
      
      final favoriteFiles = await getFavoriteFiles();
      
      if (document.isFavorite) {
        // 添加到收藏
        favoriteFiles.removeWhere((file) => file.filePath == document.filePath);
        favoriteFiles.insert(0, document);
      } else {
        // 从收藏中移除
        favoriteFiles.removeWhere((file) => file.filePath == document.filePath);
      }
      
      // 保存收藏列表
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = jsonEncode(
        favoriteFiles.map((file) => file.toJson()).toList(),
      );
      
      await prefs.setString(_favoritesKey, favoritesJson);
      
      // 同时保存阅读进度
      await saveReadingProgress(document);
    } catch (e) {
      throw PDFServiceException('切换收藏状态时发生错误', e.toString());
    }
  }

  /// 清除所有阅读数据
  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取所有键
      final keys = prefs.getKeys();
      
      // 移除相关的键
      for (final key in keys) {
        if (key == _recentFilesKey || 
            key == _favoritesKey || 
            key.startsWith(_readingProgressKey)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      throw PDFServiceException('清除数据时发生错误', e.toString());
    }
  }

  /// 获取应用文档目录
  static Future<String> getDocumentsDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } catch (e) {
      throw PDFServiceException('获取文档目录时发生错误', e.toString());
    }
  }

  /// 检查PDF文件是否有效
  static Future<bool> isValidPDFFile(String filePath) async {
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        return false;
      }

      // 检查文件扩展名
      if (!filePath.toLowerCase().endsWith('.pdf')) {
        return false;
      }

      // 检查文件大小
      final fileSize = await file.length();
      if (fileSize == 0) {
        return false;
      }

      // 简单检查PDF文件头
      final bytes = await file.openRead(0, 5).first;
      final header = String.fromCharCodes(bytes);
      
      return header.startsWith('%PDF');
    } catch (e) {
      return false;
    }
  }
}
