import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/pdf_document.dart';
import '../models/ocr_document.dart';
import '../models/ocr_status.dart';
import 'pdf_service.dart';

/// 书架服务 - 管理PDF文件的展示和交互
class BookShelfService extends ChangeNotifier {
  List<dynamic> _documents = [];
  bool _isLoading = false;
  bool _isMultiSelectMode = false;
  final Set<String> _selectedDocuments = {};
  String _searchQuery = '';

  // Getters
  List<dynamic> get documents => _documents;
  bool get isLoading => _isLoading;
  bool get isMultiSelectMode => _isMultiSelectMode;
  Set<String> get selectedDocuments => _selectedDocuments;
  String get searchQuery => _searchQuery;
  bool get hasDocuments => _documents.isNotEmpty;
  int get selectedCount => _selectedDocuments.length;

  /// 获取过滤后的文档列表
  List<dynamic> get filteredDocuments {
    if (_searchQuery.isEmpty) {
      return _documents;
    }
    
    return _documents.where((doc) {
      if (doc is OcrDocument) {
        return doc.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
      } else if (doc is PDFDocument) {
        return doc.fileName.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return false;
    }).toList();
  }

  /// 初始化书架，加载所有PDF文档
  Future<void> initialize() async {
    _setLoading(true);
    try {
      // 🔥 修复：确保 _documents 保持 dynamic 类型
      final pdfDocs = await PDFService.getRecentFiles();
      _documents = List<dynamic>.from(pdfDocs);
      await _loadDocuments(); // 加载 OCR 文档
      _sortDocuments();
    } catch (e) {
      debugPrint('初始化书架失败: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 刷新书架
  Future<void> refresh() async {
    await initialize();
  }

  /// 清理所有数据（调试用）
  Future<void> clearAllData() async {
    try {
      // 清理内存数据
      _documents.clear();
      _selectedDocuments.clear();
      
      // 清理持久化数据
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ocr_documents');
      
      // 清理文件系统中的OCR文档
      final appDir = await getApplicationDocumentsDirectory();
      final ocrDir = Directory('${appDir.path}/ocr_documents');
      if (await ocrDir.exists()) {
        await ocrDir.delete(recursive: true);
      }
      
      notifyListeners();
      print('✅ [清理] 所有数据已清理');
    } catch (e) {
      debugPrint('清理数据失败: $e');
    }
  }

  /// 添加PDF文档到书架
  Future<void> addDocument(PDFDocument document) async {
    _setLoading(true);
    try {
      // 检查是否已存在
      final existingIndex = _documents.indexWhere((doc) {
        if (doc is PDFDocument) {
          return doc.filePath == document.filePath;
        }
        return false;
      });
      
      if (existingIndex != -1) {
        // 更新现有文档
        _documents[existingIndex] = document;
      } else {
        // 添加新文档
        _documents.add(document);
      }
      
      _sortDocuments();
      notifyListeners();
    } catch (e) {
      debugPrint('添加文档失败: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// 删除单个文档
  Future<void> deleteDocument(PDFDocument document) async {
    try {
      // 从最近文件列表中移除
      await PDFService.removeFromRecentFiles(document.filePath);
      
      // 删除本地文件（可选，根据需求决定）
      final file = File(document.filePath);
      if (await file.exists()) {
        // 注意：这里删除的是用户选择的原始文件，需要谨慎处理
        // 在实际应用中，可能需要确认用户是否要删除原始文件
        // await file.delete();
      }
      
      // 从内存中移除
      _documents.removeWhere((doc) {
        if (doc is PDFDocument) {
          return doc.filePath == document.filePath;
        }
        return false;
      });
      _selectedDocuments.remove(document.filePath);
      
      notifyListeners();
    } catch (e) {
      debugPrint('删除文档失败: $e');
      rethrow;
    }
  }

  /// 批量删除选中的文档
  Future<void> deleteSelectedDocuments() async {
    if (_selectedDocuments.isEmpty) return;
    
    _setLoading(true);
    try {
      final documentsToDelete = _documents.where((doc) {
        if (doc is PDFDocument) {
          return _selectedDocuments.contains(doc.filePath);
        }
        return false;
      }).cast<PDFDocument>().toList();
      
      for (final document in documentsToDelete) {
        await deleteDocument(document);
      }
      
      _selectedDocuments.clear();
      _exitMultiSelectMode();
    } catch (e) {
      debugPrint('批量删除文档失败: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// 进入多选模式
  void enterMultiSelectMode() {
    _isMultiSelectMode = true;
    _selectedDocuments.clear();
    notifyListeners();
  }

  /// 退出多选模式
  void exitMultiSelectMode() {
    _exitMultiSelectMode();
  }

  void _exitMultiSelectMode() {
    _isMultiSelectMode = false;
    _selectedDocuments.clear();
    notifyListeners();
  }

  /// 切换文档选中状态
  void toggleDocumentSelection(PDFDocument document) {
    if (_selectedDocuments.contains(document.filePath)) {
      _selectedDocuments.remove(document.filePath);
    } else {
      _selectedDocuments.add(document.filePath);
    }
    notifyListeners();
  }

  /// 检查文档是否被选中
  bool isDocumentSelected(PDFDocument document) {
    return _selectedDocuments.contains(document.filePath);
  }

  /// 全选/取消全选
  void toggleSelectAll() {
    if (_selectedDocuments.length == filteredDocuments.length) {
      // 取消全选
      _selectedDocuments.clear();
    } else {
      // 全选
      _selectedDocuments.clear();
      _selectedDocuments.addAll(
        filteredDocuments.where((doc) => doc is PDFDocument).map((doc) => (doc as PDFDocument).filePath),
      );
    }
    notifyListeners();
  }

  /// 设置搜索查询
  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  /// 清除搜索
  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  /// 切换收藏状态
  Future<void> toggleFavorite(PDFDocument document) async {
    try {
      await PDFService.toggleFavorite(document);
      
      // 更新内存中的文档状态
      final index = _documents.indexWhere((doc) {
        if (doc is PDFDocument) {
          return doc.filePath == document.filePath;
        }
        return false;
      });
      if (index != -1) {
        _documents[index] = document;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('切换收藏状态失败: $e');
      rethrow;
    }
  }

  /// 按最后阅读时间排序文档
  void _sortDocuments() {
    _documents.sort((a, b) {
      DateTime aTime, bTime;
      
      if (a is OcrDocument) {
        aTime = a.lastAccessedTime;
      } else if (a is PDFDocument) {
        aTime = a.lastReadTime;
      } else {
        aTime = DateTime.now();
      }
      
      if (b is OcrDocument) {
        bTime = b.lastAccessedTime;
      } else if (b is PDFDocument) {
        bTime = b.lastReadTime;
      } else {
        bTime = DateTime.now();
      }
      
      return bTime.compareTo(aTime);
    });
  }

  /// 设置加载状态
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// 获取文档统计信息
  Map<String, int> getStatistics() {
    final totalDocuments = _documents.length;
    final favoriteDocuments = _documents.where((doc) {
      if (doc is PDFDocument) {
        return doc.isFavorite;
      }
      return false;
    }).length;
    final documentsWithBookmarks = _documents.where((doc) {
      if (doc is PDFDocument) {
        return doc.bookmarks.isNotEmpty;
      }
      return false;
    }).length;
    
    return {
      'total': totalDocuments,
      'favorites': favoriteDocuments,
      'bookmarked': documentsWithBookmarks,
    };
  }

  /// 添加 OCR 文档到书架
  Future<void> addOcrDocument(OcrDocument document) async {
    print('\n📚 [添加文档] 开始');
    print('   🆔 Job ID: ${document.jobId}');
    print('   📄 文件名: ${document.displayName}');
    print('   📂 PDF路径: ${document.pdfFilePath}');
    
    _setLoading(true);
    try {
      // 🔥 直接添加 OcrDocument，不转换
      _documents.add(document);
      
      print('   ✅ 已添加到内存列表');
      print('   📊 当前总数: ${_documents.length}');
      
      await _saveDocuments();
      
      print('   ✅ 已保存到持久化存储');
      
      notifyListeners();
      
      print('   ✅ 已通知监听者刷新UI');
      print('📚 [添加文档] 完成\n');
    } catch (e) {
      debugPrint('添加OCR文档失败: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// 更新 OCR 状态
  void updateOcrStatus(String jobId, OcrDocument document) {
    try {
      // 找到对应的文档
      final index = _documents.indexWhere((doc) {
        if (doc is OcrDocument) {
          return doc.jobId == jobId;
        }
        return false;
      });
      
      if (index != -1) {
        // 更新文档状态
        _documents[index] = document;
        notifyListeners();
        print('✅ [BookShelf] OCR状态已更新: $jobId -> ${document.ocrStatus}');
      }
    } catch (e) {
      debugPrint('更新OCR状态失败: $e');
    }
  }

  /// 更新 OCR 结果
  void updateOcrResult(String jobId, Map<String, dynamic> result) {
    print('\n📚 [更新] 开始更新OCR结果');
    print('   🆔 目标Job ID: $jobId');
    print('   📦 更新数据: $result');
    print('   📊 当前文档数: ${_documents.length}');
    
    // 打印所有文档的Job ID用于调试
    for (var i = 0; i < _documents.length; i++) {
      final doc = _documents[i];
      if (doc is OcrDocument) {
        print('   📄 [$i] Job ID: "${doc.jobId}"');  // 🔥 注意引号
      }
    }
    
    try {
      // 1. 首先尝试通过Job ID精确匹配
      int index = _documents.indexWhere((doc) {
        if (doc is OcrDocument) {
          final match = doc.jobId == jobId;
          print('   🔍 比较: "${doc.jobId}" == "$jobId" ? $match');
          return match;
        }
        return false;
      });

      // 2. 🔥 备用策略：如果通过Job ID找不到，尝试通过PDF路径匹配
      if (index == -1) {
        print('   ⚠️ 通过Job ID未找到，尝试通过路径匹配...');
        
        final mdPath = result['markdownFilePath'] as String?;
        if (mdPath != null && mdPath.contains(jobId)) {
          index = _documents.indexWhere((doc) {
            if (doc is OcrDocument) {
              return doc.pdfFilePath?.contains(jobId) ?? false;
            }
            return false;
          });
          
          if (index != -1) {
            print('   ✅ 通过路径找到了文档');
          }
        }
      }

      // 3. 🔥 作为最后手段，更新最后一个OcrDocument（如果只有一个）
      if (index == -1) {
        print('   ❌ 完全找不到文档');
        final ocrDocs = _documents.whereType<OcrDocument>().toList();
        if (ocrDocs.length == 1) {
          print('   💡 只有一个OCR文档，直接更新它');
          index = _documents.indexOf(ocrDocs.first);
        } else {
          print('   ❌ 无法确定要更新的文档，放弃更新');
          return;
        }
      }

      if (index != -1 && _documents[index] is OcrDocument) {
        final oldDoc = _documents[index] as OcrDocument;
        
        print('   📋 更新前状态:');
        print('      MD路径: ${oldDoc.markdownFilePath}');
        print('      状态: ${oldDoc.ocrStatus}');
        
        // 使用 copyWith 更新字段
        _documents[index] = oldDoc.copyWith(
          ocrStatus: OcrStatus.completed,
          markdownFilePath: result['markdownFilePath'] as String?,
          imagesDirectoryPath: result['imagesDirectoryPath'] as String?,
          metadataFilePath: result['metadataFilePath'] as String?,
          completedAt: DateTime.now(),
          progress: 100,
        );
        
        final newDoc = _documents[index] as OcrDocument;
        
        print('   📋 更新后状态:');
        print('      MD路径: ${newDoc.markdownFilePath}');
        print('      状态: ${newDoc.ocrStatus}');
        
        // 保存并通知
        _saveDocuments();
        notifyListeners();
        
        print('   ✅ 更新完成并已通知UI');
        print('📚 [更新] 结束\n');
      }
    } catch (e, stackTrace) {
      print('❌ [更新] 更新OCR结果失败: $e');
      print('📍 [堆栈] $stackTrace');
      debugPrint('更新OCR结果失败: $e');
    }
  }

  /// 将 OcrDocument 转换为 PDFDocument
  PDFDocument _convertOcrToPdfDocument(OcrDocument ocrDoc) {
    // 创建一个临时的文件路径用于显示
    final tempPath = '/ocr/${ocrDoc.jobId}/${ocrDoc.originalFilename}';
    
    return PDFDocument(
      filePath: tempPath,
      fileName: ocrDoc.originalFilename,
      fileSize: ocrDoc.fileSize,
      totalPages: 0, // 暂时设为0，后续可以从OCR结果中获取
      lastReadTime: ocrDoc.uploadTime,
      isFavorite: false,
      bookmarks: [],
      // 可以添加 OCR 相关的额外字段
      // ocrStatus: ocrDoc.ocrStatus,
      // ocrProgress: ocrDoc.progress,
    );
  }

  /// 保存文档列表到本地存储
  Future<void> _saveDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ocrDocuments = _documents.whereType<OcrDocument>().toList();
      
      if (ocrDocuments.isNotEmpty) {
        final jsonList = ocrDocuments.map((doc) => doc.toJson()).toList();
        await prefs.setString('ocr_documents', json.encode(jsonList));
        print('✅ [BookShelf] OCR 文档已保存: ${ocrDocuments.length} 个');
      }
    } catch (e) {
      debugPrint('保存文档失败: $e');
    }
  }

  /// 从本地存储加载文档列表
  Future<void> _loadDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('ocr_documents');
      
      if (jsonString != null) {
        final jsonList = json.decode(jsonString) as List<dynamic>;
        final ocrDocuments = jsonList.map((json) => OcrDocument.fromJson(json as Map<String, dynamic>)).toList();
        
        // 🔥 直接添加 OCR 文档，不转换
        for (final ocrDoc in ocrDocuments) {
          _documents.add(ocrDoc);
        }
        
        print('✅ [BookShelf] OCR 文档已加载: ${ocrDocuments.length} 个');
      }
    } catch (e) {
      debugPrint('加载文档失败: $e');
    }
  }

  @override
  void dispose() {
    _documents.clear();
    _selectedDocuments.clear();
    super.dispose();
  }
}
