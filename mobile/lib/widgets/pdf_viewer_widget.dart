import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfViewerWidget extends StatefulWidget {
  final String pdfPath;
  final String? title;

  const PdfViewerWidget({
    Key? key,
    required this.pdfPath,
    this.title,
  }) : super(key: key);

  @override
  State<PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<PdfViewerWidget> {
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;
  String _errorMessage = '';
  PDFViewController? _pdfViewController;

  @override
  Widget build(BuildContext context) {
    print('📱 [PDF Widget] 构建 PDF 查看器');
    print('   📂 路径: ${widget.pdfPath}');
    print('   ✓ 文件存在: ${File(widget.pdfPath).existsSync()}');

    return Column(
      children: [
        // 工具栏
        _buildToolbar(),
        
        // PDF 内容
        Expanded(
          child: _buildPdfContent(),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 页码显示
          Text(
            _isReady
                ? '第 ${_currentPage + 1} 页 / 共 $_totalPages 页'
                : '加载中...',
            style: TextStyle(fontSize: 14),
          ),
          
          // 翻页按钮
          if (_isReady) ...[
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0
                      ? () => _goToPage(_currentPage - 1)
                      : null,
                  tooltip: '上一页',
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right),
                  onPressed: _currentPage < _totalPages - 1
                      ? () => _goToPage(_currentPage + 1)
                      : null,
                  tooltip: '下一页',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPdfContent() {
    final file = File(widget.pdfPath);

    if (!file.existsSync()) {
      return _buildErrorView('PDF 文件不存在');
    }

    return Stack(
      children: [
        PDFView(
          filePath: widget.pdfPath,
          enableSwipe: true,  // 允许滑动翻页
          swipeHorizontal: false,  // 垂直滑动
          autoSpacing: true,  // 自动间距
          pageFling: true,  // 快速翻页
          pageSnap: true,  // 页面对齐
          defaultPage: _currentPage,
          fitPolicy: FitPolicy.WIDTH,  // 适应宽度
          preventLinkNavigation: false,  // 允许链接导航
          
          onRender: (pages) {
            setState(() {
              _totalPages = pages ?? 0;
              _isReady = true;
            });
            print('✅ [PDF] 渲染完成: $_totalPages 页');
          },
          
          onError: (error) {
            setState(() {
              _errorMessage = error.toString();
            });
            print('❌ [PDF] 渲染错误: $error');
          },
          
          onPageError: (page, error) {
            print('❌ [PDF] 第 $page 页错误: $error');
          },
          
          onViewCreated: (PDFViewController controller) {
            _pdfViewController = controller;
            print('✅ [PDF] 控制器已创建');
          },
          
          onPageChanged: (int? page, int? total) {
            if (page != null) {
              setState(() {
                _currentPage = page;
              });
              print('📄 [PDF] 切换到第 ${page + 1} 页');
            }
          },
        ),
        
        // 加载指示器
        if (!_isReady)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('加载 PDF 中...'),
              ],
            ),
          ),
        
        // 错误提示
        if (_errorMessage.isNotEmpty)
          Center(
            child: _buildErrorView(_errorMessage),
          ),
      ],
    );
  }

  Widget _buildErrorView(String message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red),
        SizedBox(height: 16),
        Text('加载失败', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  void _goToPage(int page) {
    if (_pdfViewController != null) {
      _pdfViewController!.setPage(page);
      print('📄 [PDF] 跳转到第 ${page + 1} 页');
    }
  }
}
