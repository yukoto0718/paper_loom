import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/pdf_document.dart';
import 'pdf_service.dart';

/// 书架服务 - 管理PDF文件的展示和交互
class BookShelfService extends ChangeNotifier {
  List<PDFDocument> _documents = [];
  bool _isLoading = false;
  bool _isMultiSelectMode = false;
  final Set<String> _selectedDocuments = {};
  String _searchQuery = '';

  // Getters
  List<PDFDocument> get documents => _documents;
  bool get isLoading => _isLoading;
  bool get isMultiSelectMode => _isMultiSelectMode;
  Set<String> get selectedDocuments => _selectedDocuments;
  String get searchQuery => _searchQuery;
  bool get hasDocuments => _documents.isNotEmpty;
  int get selectedCount => _selectedDocuments.length;

  /// 获取过滤后的文档列表
  List<PDFDocument> get filteredDocuments {
    if (_searchQuery.isEmpty) {
      return _documents;
    }
    
    return _documents.where((doc) {
      return doc.fileName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  /// 初始化书架，加载所有PDF文档
  Future<void> initialize() async {
    _setLoading(true);
    try {
      _documents = await PDFService.getRecentFiles();
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

  /// 添加PDF文档到书架
  Future<void> addDocument(PDFDocument document) async {
    _setLoading(true);
    try {
      // 检查是否已存在
      final existingIndex = _documents.indexWhere(
        (doc) => doc.filePath == document.filePath,
      );
      
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
      _documents.removeWhere((doc) => doc.filePath == document.filePath);
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
      final documentsToDelete = _documents.where(
        (doc) => _selectedDocuments.contains(doc.filePath),
      ).toList();
      
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
        filteredDocuments.map((doc) => doc.filePath),
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
      final index = _documents.indexWhere(
        (doc) => doc.filePath == document.filePath,
      );
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
    _documents.sort((a, b) => b.lastReadTime.compareTo(a.lastReadTime));
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
    final favoriteDocuments = _documents.where((doc) => doc.isFavorite).length;
    final documentsWithBookmarks = _documents.where((doc) => doc.bookmarks.isNotEmpty).length;
    
    return {
      'total': totalDocuments,
      'favorites': favoriteDocuments,
      'bookmarked': documentsWithBookmarks,
    };
  }

  @override
  void dispose() {
    _documents.clear();
    _selectedDocuments.clear();
    super.dispose();
  }
}
