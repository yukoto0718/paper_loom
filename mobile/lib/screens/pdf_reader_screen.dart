import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../models/pdf_document.dart';
import '../services/pdf_service.dart';

/// PDF阅读器屏幕
class PDFReaderScreen extends StatefulWidget {
  final PDFDocument document;

  const PDFReaderScreen({
    super.key,
    required this.document,
  });

  @override
  State<PDFReaderScreen> createState() => _PDFReaderScreenState();
}

class _PDFReaderScreenState extends State<PDFReaderScreen> {
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isReady = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('PDF Reader: Starting with file: ${widget.document.fileName}');
    debugPrint('PDF Reader: File path: ${widget.document.filePath}');
  }

  @override
  void dispose() {
    // 保存阅读进度
    _saveProgress();
    super.dispose();
  }

  /// 保存阅读进度
  Future<void> _saveProgress() async {
    if (_totalPages > 0) {
      try {
        widget.document.currentPage = _currentPage + 1; // 转换为1基索引
        await PDFService.saveReadingProgress(widget.document);
        debugPrint('PDF Reader: Progress saved - page: ${_currentPage + 1}');
      } catch (e) {
        debugPrint('PDF Reader: Failed to save progress: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.document.fileName,
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          if (_isReady)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          if (_isReady)
            IconButton(
              icon: Icon(
                widget.document.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: widget.document.isFavorite ? Colors.red[300] : Colors.white,
              ),
              onPressed: _toggleFavorite,
              tooltip: widget.document.isFavorite ? '取消收藏' : '添加收藏',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showDocumentInfo,
            tooltip: '文档信息',
          ),
        ],
      ),
      backgroundColor: Colors.grey[200],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    return Stack(
      children: [
        PDFView(
          filePath: widget.document.filePath,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: false,
          pageFling: true,
          pageSnap: true,
          defaultPage: widget.document.currentPage - 1, // 转换为0基索引
          fitPolicy: FitPolicy.WIDTH,
          preventLinkNavigation: false,
          onRender: (pages) {
            debugPrint('PDF Reader: PDF rendered with $pages pages');
            setState(() {
              _totalPages = pages ?? 0;
              _isReady = true;
            });
          },
          onViewCreated: (PDFViewController pdfViewController) {
            debugPrint('PDF Reader: PDF view created');
          },
          onPageChanged: (int? page, int? total) {
            debugPrint('PDF Reader: Page changed to $page of $total');
            if (page != null) {
              setState(() {
                _currentPage = page;
              });
            }
          },
          onError: (error) {
            debugPrint('PDF Reader: Error occurred: $error');
            setState(() {
              _errorMessage = error.toString();
            });
          },
          onPageError: (page, error) {
            debugPrint('PDF Reader: Page error on page $page: $error');
          },
        ),
        
        // 加载指示器
        if (!_isReady && _errorMessage == null)
          Container(
            color: Colors.white.withValues(alpha: 0.9),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    '正在加载PDF...',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'PDF加载失败',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '文件: ${widget.document.fileName}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '未知错误',
              style: const TextStyle(fontSize: 12, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _isReady = false;
                    });
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 切换收藏状态
  Future<void> _toggleFavorite() async {
    try {
      await PDFService.toggleFavorite(widget.document);
      setState(() {});
      
      final message = widget.document.isFavorite ? '已添加到收藏' : '已从收藏中移除';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('PDF Reader: Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 显示文档信息
  void _showDocumentInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('文档信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('文件名', widget.document.fileName),
            _buildInfoRow('文件大小', widget.document.formattedFileSize),
            _buildInfoRow('总页数', '$_totalPages 页'),
            _buildInfoRow('当前页面', '${_currentPage + 1} 页'),
            _buildInfoRow('阅读进度', '${_totalPages > 0 ? (((_currentPage + 1) / _totalPages * 100).toStringAsFixed(1)) : "0.0"}%'),
            _buildInfoRow('收藏状态', widget.document.isFavorite ? '已收藏' : '未收藏'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
