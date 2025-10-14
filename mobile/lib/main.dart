import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'screens/pdf_reader_screen.dart';
import 'screens/document_reader_screen.dart';
import 'services/pdf_service.dart';
import 'services/book_shelf_service.dart';
import 'services/permission_service.dart';
import 'services/ocr_api_service.dart';
import 'services/file_storage_service.dart';
import 'models/pdf_document.dart';
import 'models/ocr_document.dart';
import 'models/ocr_status.dart';
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

  /// 添加PDF文件 - 集成OCR处理流程（完全重写版本）
  Future<void> _addPDFFile() async {
    print('\n========== 开始上传流程 ==========');
    setState(() => _isLoading = true);

    try {
      // Step 1: 权限检查
      print('🔐 [Step 1] 检查权限...');
      final permissionStatus = await PermissionService.getDetailedPermissionStatus();
      
      if (!permissionStatus.hasPermission) {
        if (permissionStatus.isPermanentlyDenied) {
          print('❌ [Step 1] 权限被永久拒绝');
          _showPermissionDeniedDialog();
          return;
        } else if (permissionStatus.needsRequest) {
          print('🔐 [Step 1] 请求权限...');
          final granted = await PermissionService.requestStoragePermissions();
          if (!granted) {
            print('❌ [Step 1] 权限被拒绝');
            _showSnackBar('需要存储权限来选择PDF文件');
            return;
          }
        }
      }
      print('✅ [Step 1] 权限检查通过');

      // Step 2: 选择文件
      print('📂 [Step 2] 开始选择文件...');
      final filePath = await PDFService.pickPDFFile();
      if (filePath == null) {
        print('❌ [Step 2] 用户取消选择');
        return;
      }

      final pickedFile = File(filePath);
      final fileName = pickedFile.path.split('/').last;
      
      print('✅ [Step 2] 文件已选择');
      print('   📄 文件名: $fileName');
      print('   📂 原始路径: ${pickedFile.path}');
      print('   📏 文件大小: ${await pickedFile.length()} bytes');
      print('   ✓ 文件存在: ${pickedFile.existsSync()}');

      // Step 3: 立即保存 PDF 副本（关键！）
      print('\n💾 [Step 3] 立即保存 PDF 副本...');
      
      // 生成临时 ID
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      print('   🔑 临时ID: $tempId');
      
      // 获取保存目录
      final tempDir = await FileStorageService.getJobDirectory(tempId);
      final savedPdfPath = '${tempDir.path}/original.pdf';
      
      print('   📂 目标路径: $savedPdfPath');
      
      // 🔥 强制复制文件
      await pickedFile.copy(savedPdfPath);
      
      // 🔥 验证文件确实被保存
      final savedFile = File(savedPdfPath);
      final savedExists = savedFile.existsSync();
      final savedSize = savedExists ? await savedFile.length() : 0;
      
      print('✅ [Step 3] PDF 副本保存完成');
      print('   ✓ 文件存在: $savedExists');
      print('   ✓ 文件大小: $savedSize bytes');
      
      if (!savedExists || savedSize == 0) {
        throw Exception('PDF 保存失败：文件不存在或大小为0');
      }

      // Step 4: 上传到后端
      print('\n📤 [Step 4] 开始上传到后端...');
      _showSnackBar('正在上传 $fileName...');
      
      final uploadResponse = await OcrApiService().uploadPdf(
        savedFile,  // 🔥 使用保存的副本上传
        onProgress: (sent, total) {
          final progress = (sent / total * 100).toStringAsFixed(0);
          print('   ⬆️ 上传进度: $progress%');
        },
      );

      if (!uploadResponse.success || uploadResponse.data == null) {
        print('❌ [Step 4] 上传失败: ${uploadResponse.message}');
        await tempDir.delete(recursive: true);
        _showSnackBar('上传失败: ${uploadResponse.message}');
        return;
      }

      final jobId = uploadResponse.data!['job_id'] as String;
      print('✅ [Step 4] 上传成功');
      print('   🆔 Job ID: $jobId');

      // Step 5: 重命名目录为实际 job_id
      print('\n📝 [Step 5] 重命名目录...');
      final actualDir = await FileStorageService.getJobDirectory(jobId);
      
      // 如果目标目录已存在，先删除
      if (await actualDir.exists()) {
        await actualDir.delete(recursive: true);
      }
      
      await tempDir.rename(actualDir.path);
      final finalPdfPath = '${actualDir.path}/original.pdf';
      
      // 🔥 再次验证最终路径
      final finalExists = File(finalPdfPath).existsSync();
      print('✅ [Step 5] 目录重命名完成');
      print('   📂 最终路径: $finalPdfPath');
      print('   ✓ 文件存在: $finalExists');
      
      if (!finalExists) {
        throw Exception('重命名后文件丢失');
      }

      // Step 6: 启动 OCR 处理
      print('\n🚀 [Step 6] 启动 OCR 处理...');
      _showSnackBar('上传成功，开始识别...');
      
      final processResponse = await OcrApiService().startProcessing(jobId);
      
      if (!processResponse.success) {
        print('❌ [Step 6] 启动失败: ${processResponse.message}');
        _showSnackBar('启动处理失败: ${processResponse.message}');
        return;
      }
      print('✅ [Step 6] OCR 处理已启动');

      // Step 7: 创建 OcrDocument
      print('\n📋 [Step 7] 创建文档对象...');
      final ocrDoc = OcrDocument.fromApiResponse(
        uploadResponse.data!,
        pdfFilePath: finalPdfPath,  // 🔥 使用验证过的路径
      );
      
      print('✅ [Step 7] 文档对象已创建');
      print('   🆔 Job ID: ${ocrDoc.jobId}');
      print('   📂 PDF路径: ${ocrDoc.pdfFilePath}');

      // Step 8: 添加到书架
      print('\n📚 [Step 8] 添加到书架...');
      await _bookShelfService.addOcrDocument(ocrDoc);
      print('✅ [Step 8] 已添加到书架');

      // Step 9: 开始轮询
      print('\n🔄 [Step 9] 开始轮询状态...');
      _pollOcrStatus(jobId);
      print('✅ [Step 9] 轮询已启动');
      
      print('\n========== 上传流程完成 ==========\n');

    } catch (e, stackTrace) {
      print('\n❌ ========== 错误发生 ==========');
      print('错误: $e');
      print('堆栈: $stackTrace');
      print('=====================================\n');
      _showSnackBar('操作失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 后台轮询 OCR 状态
  Future<void> _pollOcrStatus(String jobId) async {
    try {
      // 使用 OcrApiService 的轮询功能
      await OcrApiService().pollUntilCompleted(
        jobId,
        onStatusUpdate: (document) {
          // 更新 UI 状态
          print('OCR 状态: ${document.ocrStatus}, 进度: ${document.progress}%');
          
          // 更新书架中的文档状态
          _bookShelfService.updateOcrStatus(jobId, document);
        },
        pollInterval: 3, // 3秒轮询一次
        maxPollingTime: 300, // 5分钟超时
      );
      
      // 处理完成，下载结果
      _showSnackBar('识别完成，正在下载结果...');
      await _downloadOcrResult(jobId);
      
    } catch (e) {
      print('轮询错误: $e');
      _showSnackBar('识别失败: $e');
      _bookShelfService.updateOcrStatus(jobId, OcrDocument(
        jobId: jobId,
        originalFilename: '',
        fileSize: 0,
        uploadTime: DateTime.now(),
        ocrStatus: OcrStatus.failed,
        errorMessage: e.toString(),
      ));
    }
  }

  /// 下载 OCR 结果
  Future<void> _downloadOcrResult(String jobId) async {
    try {
      print('📥 [下载] 开始下载 OCR 结果...');
      
      // 1. 获取存储目录
      final jobDir = await FileStorageService.getJobDirectory(jobId);
      final zipPath = '${jobDir.path}/result.zip';
      
      print('📥 [下载] 目标路径: $zipPath');

      // 2. 下载 ZIP 文件
      await OcrApiService().downloadZip(
        jobId,
        zipPath,
        onProgress: (received, total) {
          final progress = (received / total * 100).toStringAsFixed(0);
          print('📥 [下载] 进度: $progress%');
          // 可选：更新 UI 进度
        },
      );
      
      print('✅ [下载] ZIP 下载完成');

      // 3. 解压 ZIP 文件
      print('📦 [解压] 开始解压...');
      final extractedPaths = await FileStorageService.extractZip(
        zipPath,
        jobDir.path,
      );
      
      print('✅ [解压] 解压完成');
      print('📄 Markdown: ${extractedPaths['markdown']}');
      print('🖼️ Images: ${extractedPaths['images']}');

      // 4. 删除 ZIP 文件（节省空间）
      await File(zipPath).delete();
      print('🗑️ [清理] ZIP 文件已删除');

      // 5. 更新文档模型
      print('📋 [更新] 开始更新文档模型');
      print('   🆔 Job ID: $jobId');
      print('   📄 Markdown路径: ${extractedPaths['markdown']}');
      print('   🖼️ 图片路径: ${extractedPaths['images']}');
      
      _bookShelfService.updateOcrResult(jobId, {
        'status': 'completed',
        'markdownFilePath': extractedPaths['markdown'],
        'imagesDirectoryPath': extractedPaths['images'],
        'metadataFilePath': extractedPaths['metadata'],
      });

      // 🔥 强制等待一下，确保更新完成
      await Future.delayed(Duration(milliseconds: 500));
      
      // 🔥 验证更新是否成功
      final docs = _bookShelfService.documents.whereType<OcrDocument>();
      final updatedDoc = docs.firstWhere(
        (d) => d.jobId == jobId,
        orElse: () => throw Exception('更新后找不到文档'),
      );
      
      print('🔍 [验证] 更新后的文档:');
      print('   🆔 Job ID: ${updatedDoc.jobId}');
      print('   📄 MD路径: ${updatedDoc.markdownFilePath}');
      print('   🖼️ 图片路径: ${updatedDoc.imagesDirectoryPath}');
      print('   📊 状态: ${updatedDoc.ocrStatus}');
      
      if (updatedDoc.markdownFilePath == null) {
        print('   ❌ MD路径仍然是null，更新失败！');
        throw Exception('Markdown路径更新失败');
      }
      
      print('   ✅ 验证成功');

      _showSnackBar('识别完成！可以开始阅读了');
      print('✅ [完成] OCR 结果已就绪');
      
    } catch (e, stackTrace) {
      print('❌ [下载] 失败: $e');
      print('📍 [堆栈] $stackTrace');
      _showSnackBar('下载失败: $e');
      
      _bookShelfService.updateOcrStatus(jobId, OcrDocument(
        jobId: jobId,
        originalFilename: '',
        fileSize: 0,
        uploadTime: DateTime.now(),
        ocrStatus: OcrStatus.failed,
        errorMessage: e.toString(),
      ));
    }
  }


  /// 打开文档
  Future<void> _openDocument(dynamic document) async {
    try {
      if (document is OcrDocument) {
        // 使用新的双模式阅读器
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocumentReaderScreen(document: document),
            ),
          ).then((_) {
            // 返回时刷新书架
            _bookShelfService.refresh();
          });
        }
      } else if (document is PDFDocument) {
        // 检查文件是否仍然存在
        if (!await PDFService.isValidPDFFile(document.filePath)) {
          _showSnackBar('文件不存在或已损坏');
          await _bookShelfService.deleteDocument(document);
          return;
        }

        // 使用原有的 PDF 阅读器
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

  /// 显示清理数据确认对话框
  void _showClearDataDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('清理数据'),
          content: const Text('确定要清理所有数据吗？这将删除所有文档和OCR结果。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _bookShelfService.clearAllData();
                _showSnackBar('数据已清理');
              },
              child: const Text('清理'),
            ),
          ],
        );
      },
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
              
              // 清理数据按钮（调试用）
              IconButton(
                onPressed: () => _showClearDataDialog(),
                icon: const Icon(Icons.clear_all),
                tooltip: '清理数据',
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

    // 混合文档网格 - 支持 PDFDocument 和 OcrDocument
    final pdfDocuments = filteredDocuments.whereType<PDFDocument>().toList();
    final ocrDocuments = filteredDocuments.whereType<OcrDocument>().toList();

    // 如果只有 OCR 文档，显示 OCR 文档网格
    if (ocrDocuments.isNotEmpty && pdfDocuments.isEmpty) {
      return _buildOcrDocumentGrid(ocrDocuments);
    }
    
    // 如果只有 PDF 文档，显示 PDF 文档网格
    if (pdfDocuments.isNotEmpty && ocrDocuments.isEmpty) {
      return PDFBookGrid(
        documents: pdfDocuments,
        isMultiSelectMode: _bookShelfService.isMultiSelectMode,
        selectedDocuments: _bookShelfService.selectedDocuments,
        onDocumentTap: _openDocument,
        onDocumentLongPress: _onDocumentLongPress,
        onToggleSelection: _bookShelfService.toggleDocumentSelection,
        onToggleFavorite: _bookShelfService.toggleFavorite,
      );
    }
    
    // 混合文档，显示所有文档
    return _buildMixedDocumentGrid(pdfDocuments, ocrDocuments);
  }

  /// 构建 OCR 文档网格
  Widget _buildOcrDocumentGrid(List<OcrDocument> documents) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final document = documents[index];
        
        print('👆 [OCR卡片] 构建卡片: ${document.jobId}');
        print('📋 [OCR卡片] PDF路径: ${document.pdfFilePath}');
        print('📋 [OCR卡片] OCR状态: ${document.ocrStatus}');

        return GestureDetector(
          onTap: () {
            print('\n========== 点击文档 ==========');
            print('📋 文档类型: ${document.runtimeType}');
            
            if (document is OcrDocument) {
              print('📋 Job ID: ${document.jobId}');
              print('📋 文件名: ${document.displayName}');
              print('📋 PDF路径: ${document.pdfFilePath}');
              print('📋 MD路径: ${document.markdownFilePath}');
              print('📋 OCR状态: ${document.ocrStatus}');
              
              // 🔥 检查文件状态
              bool pdfExists = false;
              bool mdExists = false;
              
              if (document.pdfFilePath != null) {
                pdfExists = File(document.pdfFilePath!).existsSync();
                print('📂 PDF存在: $pdfExists');
              }
              
              if (document.markdownFilePath != null) {
                mdExists = File(document.markdownFilePath!).existsSync();
                print('📂 MD存在: $mdExists');
              }
              
              // 🔥 容错：只要有一个文件存在就允许打开
              if (!pdfExists && !mdExists) {
                print('❌ 两个文件都不存在');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('文件不存在，OCR可能还在处理中'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;  // 🔥 不删除文档，只是提示
              }
              
              if (!pdfExists) {
                print('⚠️ PDF不存在，但Markdown存在，允许打开');
              }
              
              // 打开阅读器
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DocumentReaderScreen(document: document),
                ),
              );
              
              print('========== 文档点击处理完成 ==========\n');
            }
          },
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面区域
                Expanded(
                  flex: 4,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              document.ocrStatus == OcrStatus.completed 
                                  ? Icons.text_snippet 
                                  : Icons.picture_as_pdf,
                              size: 48,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        // OCR 状态指示器
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getOcrStatusColor(document.ocrStatus),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getOcrStatusText(document.ocrStatus),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 信息区域
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          document.originalFilename,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.insert_drive_file,
                              size: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(width: 4),
                            Text(
                              _formatFileSize(document.fileSize),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建混合文档网格
  Widget _buildMixedDocumentGrid(List<PDFDocument> pdfDocuments, List<OcrDocument> ocrDocuments) {
    final allDocuments = [...pdfDocuments, ...ocrDocuments];
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: allDocuments.length,
      itemBuilder: (context, index) {
        final document = allDocuments[index];
        
        if (document is PDFDocument) {
          return PDFBookCard(
            document: document,
            isSelected: _bookShelfService.selectedDocuments.contains(document.filePath),
            isMultiSelectMode: _bookShelfService.isMultiSelectMode,
            onTap: () => _openDocument(document),
            onLongPress: () => _onDocumentLongPress(document),
            onToggleSelection: () => _bookShelfService.toggleDocumentSelection(document),
            onToggleFavorite: () => _bookShelfService.toggleFavorite(document),
          );
        } else if (document is OcrDocument) {
          return GestureDetector(
            onTap: () {
              print('\n========== 点击文档 ==========');
              print('📋 文档类型: ${document.runtimeType}');
              
              if (document is OcrDocument) {
                print('📋 Job ID: ${document.jobId}');
                print('📋 文件名: ${document.displayName}');
                print('📋 PDF路径: ${document.pdfFilePath}');
                print('📋 MD路径: ${document.markdownFilePath}');
                print('📋 OCR状态: ${document.ocrStatus}');
                
                // 🔥 检查文件状态
                bool pdfExists = false;
                bool mdExists = false;
                
                if (document.pdfFilePath != null) {
                  pdfExists = File(document.pdfFilePath!).existsSync();
                  print('📂 PDF存在: $pdfExists');
                }
                
                if (document.markdownFilePath != null) {
                  mdExists = File(document.markdownFilePath!).existsSync();
                  print('📂 MD存在: $mdExists');
                }
                
                // 🔥 容错：只要有一个文件存在就允许打开
                if (!pdfExists && !mdExists) {
                  print('❌ 两个文件都不存在');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('文件不存在，OCR可能还在处理中'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;  // 🔥 不删除文档，只是提示
                }
                
                if (!pdfExists) {
                  print('⚠️ PDF不存在，但Markdown存在，允许打开');
                }
                
                // 打开阅读器
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DocumentReaderScreen(document: document),
                  ),
                );
                
                print('========== 文档点击处理完成 ==========\n');
              }
            },
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 封面区域
                  Expanded(
                    flex: 4,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primaryContainer,
                            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                document.ocrStatus == OcrStatus.completed 
                                    ? Icons.text_snippet 
                                    : Icons.picture_as_pdf,
                                size: 48,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          // OCR 状态指示器
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getOcrStatusColor(document.ocrStatus),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getOcrStatusText(document.ocrStatus),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 信息区域
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            document.originalFilename,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.insert_drive_file,
                                size: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(width: 4),
                              Text(
                                _formatFileSize(document.fileSize),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return Container(); // 默认返回空容器
      },
    );
  }

  /// 获取 OCR 状态颜色
  Color _getOcrStatusColor(OcrStatus status) {
    switch (status) {
      case OcrStatus.uploaded:
        return Colors.orange;
      case OcrStatus.processing:
        return Colors.blue;
      case OcrStatus.completed:
        return Colors.green;
      case OcrStatus.failed:
        return Colors.red;
    }
  }

  /// 获取 OCR 状态文本
  String _getOcrStatusText(OcrStatus status) {
    switch (status) {
      case OcrStatus.uploaded:
        return '等待';
      case OcrStatus.processing:
        return '处理中';
      case OcrStatus.completed:
        return '完成';
      case OcrStatus.failed:
        return '失败';
    }
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
