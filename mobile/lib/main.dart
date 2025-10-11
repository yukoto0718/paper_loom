import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/pdf_reader_screen.dart';
import 'services/pdf_service.dart';
import 'services/book_shelf_service.dart';
import 'services/permission_service.dart';
import 'models/pdf_document.dart';
import 'widgets/pdf_book_card.dart';
import 'widgets/empty_shelf_widget.dart';

void main() {
  runApp(const PaperLoomApp());
}

class PaperLoomApp extends StatelessWidget {
  const PaperLoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paper Loom - PDF阅读器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // 使用现代化的Material 3设计
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const BookShelfScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/pdf-reader':
            final document = settings.arguments as PDFDocument;
            return MaterialPageRoute(
              builder: (context) => PDFReaderScreen(document: document),
            );
          default:
            return null;
        }
      },
    );
  }
}

class BookShelfScreen extends StatefulWidget {
  const BookShelfScreen({super.key});

  @override
  State<BookShelfScreen> createState() => _BookShelfScreenState();
}

class _BookShelfScreenState extends State<BookShelfScreen> {
  late BookShelfService _bookShelfService;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _bookShelfService = BookShelfService();
    _initializeBookShelf();
  }

  @override
  void dispose() {
    _bookShelfService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 初始化书架
  Future<void> _initializeBookShelf() async {
    await _bookShelfService.initialize();
  }

  /// 添加PDF文件
  Future<void> _addPDFFile() async {
    setState(() => _isLoading = true);

    try {
      // 检查并请求权限
      final permissionStatus = await PermissionService.getDetailedPermissionStatus();
      
      if (!permissionStatus.hasPermission) {
        if (permissionStatus.isPermanentlyDenied) {
          // 权限被永久拒绝，显示设置页面提示
          _showPermissionDeniedDialog();
          return;
        } else if (permissionStatus.needsRequest) {
          // 需要请求权限
          final granted = await PermissionService.requestStoragePermissions();
          if (!granted) {
            _showSnackBar('需要存储权限来选择PDF文件');
            return;
          }
        }
      }

      final filePath = await PDFService.pickPDFFile();
      
      if (filePath != null) {
        final document = await PDFService.createPDFDocument(filePath);
        await _bookShelfService.addDocument(document);
        
        if (mounted) {
          _showSnackBar('PDF文件添加成功');
        }
      }
    } on PDFServiceException catch (e) {
      if (mounted) {
        _showSnackBar(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('添加文件失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 打开PDF文档
  Future<void> _openDocument(PDFDocument document) async {
    try {
      // 检查文件是否仍然存在
      if (!await PDFService.isValidPDFFile(document.filePath)) {
        _showSnackBar('文件不存在或已损坏');
        await _bookShelfService.deleteDocument(document);
        return;
      }

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/pdf-reader',
          arguments: document,
        ).then((_) {
          // 返回时刷新书架
          _bookShelfService.refresh();
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('打开文件失败: $e');
      }
    }
  }

  /// 长按文档处理
  void _onDocumentLongPress(PDFDocument document) {
    HapticFeedback.mediumImpact();
    
    if (_bookShelfService.isMultiSelectMode) {
      _bookShelfService.toggleDocumentSelection(document);
    } else {
      _showDeleteConfirmDialog(document);
    }
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(PDFDocument document) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除确认'),
          content: Text('确定要删除《${document.fileName}》吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteDocument(document);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  /// 删除单个文档
  Future<void> _deleteDocument(PDFDocument document) async {
    try {
      await _bookShelfService.deleteDocument(document);
      _showSnackBar('文件删除成功');
    } catch (e) {
      _showSnackBar('删除文件失败: $e');
    }
  }

  /// 显示批量删除确认对话框
  void _showBatchDeleteConfirmDialog() {
    final selectedCount = _bookShelfService.selectedCount;
    if (selectedCount == 0) return;

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('批量删除确认'),
          content: Text('确定要删除选中的$selectedCount个文件吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _batchDeleteDocuments();
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  /// 批量删除文档
  Future<void> _batchDeleteDocuments() async {
    try {
      final selectedCount = _bookShelfService.selectedCount;
      await _bookShelfService.deleteSelectedDocuments();
      _showSnackBar('已删除$selectedCount个文件');
    } catch (e) {
      _showSnackBar('批量删除失败: $e');
    }
  }

  /// 搜索文档
  void _onSearchChanged(String query) {
    _bookShelfService.setSearchQuery(query);
  }

  /// 清除搜索
  void _clearSearch() {
    _searchController.clear();
    _bookShelfService.clearSearch();
  }

  /// 显示权限被拒绝的对话框
  void _showPermissionDeniedDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('需要存储权限'),
          content: Text(PermissionService.getPermissionRationaleMessage()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await PermissionService.openAppSettings();
              },
              child: const Text('去设置'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _bookShelfService,
      builder: (context, child) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // 顶部功能栏
                _buildTopBar(),
                
                // 主体内容
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
          
          // 多选模式底部栏
          bottomNavigationBar: _bookShelfService.isMultiSelectMode
              ? _buildMultiSelectBottomBar()
              : null,
        );
      },
    );
  }

  /// 构建顶部功能栏
  Widget _buildTopBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // 应用标题栏
          Row(
            children: [
              Icon(
                Icons.auto_stories,
                size: 28,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Paper Loom',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const Spacer(),
              
              // 多选按钮
              if (_bookShelfService.hasDocuments)
                IconButton(
                  onPressed: () {
                    if (_bookShelfService.isMultiSelectMode) {
                      _bookShelfService.exitMultiSelectMode();
                    } else {
                      _bookShelfService.enterMultiSelectMode();
                    }
                  },
                  icon: Icon(
                    _bookShelfService.isMultiSelectMode
                        ? Icons.close
                        : Icons.checklist,
                  ),
                  tooltip: _bookShelfService.isMultiSelectMode ? '退出多选' : '多选模式',
                ),
              
              // 刷新按钮
              IconButton(
                onPressed: _bookShelfService.refresh,
                icon: const Icon(Icons.refresh),
                tooltip: '刷新',
              ),
              
              // 添加按钮
              IconButton(
                onPressed: _isLoading ? null : _addPDFFile,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_circle_outline),
                tooltip: '添加PDF',
              ),
            ],
          ),
          
          // 搜索栏
          if (_bookShelfService.hasDocuments) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '搜索PDF文件...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _bookShelfService.searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建主体内容
  Widget _buildBody() {
    if (_bookShelfService.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final filteredDocuments = _bookShelfService.filteredDocuments;

    // 空状态
    if (!_bookShelfService.hasDocuments) {
      return EmptyShelfWidget(
        onAddPressed: _addPDFFile,
      );
    }

    // 搜索结果为空
    if (filteredDocuments.isEmpty && _bookShelfService.searchQuery.isNotEmpty) {
      return EmptySearchResultWidget(
        searchQuery: _bookShelfService.searchQuery,
        onClearSearch: _clearSearch,
      );
    }

    // PDF书本网格
    return PDFBookGrid(
      documents: filteredDocuments,
      isMultiSelectMode: _bookShelfService.isMultiSelectMode,
      selectedDocuments: _bookShelfService.selectedDocuments,
      onDocumentTap: _openDocument,
      onDocumentLongPress: _onDocumentLongPress,
      onToggleSelection: _bookShelfService.toggleDocumentSelection,
      onToggleFavorite: _bookShelfService.toggleFavorite,
    );
  }

  /// 构建多选模式底部栏
  Widget _buildMultiSelectBottomBar() {
    final selectedCount = _bookShelfService.selectedCount;
    final totalCount = _bookShelfService.filteredDocuments.length;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 全选/取消全选
            TextButton.icon(
              onPressed: _bookShelfService.toggleSelectAll,
              icon: Icon(
                selectedCount == totalCount
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              label: Text(
                selectedCount == totalCount ? '取消全选' : '全选',
              ),
            ),
            
            const Spacer(),
            
            // 选中数量
            Text(
              '已选择 $selectedCount 项',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 删除按钮
            FilledButton.icon(
              onPressed: selectedCount > 0 ? _showBatchDeleteConfirmDialog : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
            ),
          ],
        ),
      ),
    );
  }
}