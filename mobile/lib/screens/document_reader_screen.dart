import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:paper_loom/models/ocr_document.dart';
import 'package:paper_loom/models/ocr_status.dart';
import 'package:paper_loom/widgets/pdf_viewer_widget.dart';

enum ReadingMode { pdf, markdown }

class DocumentReaderScreen extends StatefulWidget {
  final OcrDocument document;

  const DocumentReaderScreen({
    Key? key,
    required this.document,
  }) : super(key: key);

  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen> {
  ReadingMode _currentMode = ReadingMode.pdf;
  String? _markdownContent;
  bool _isLoading = false;
  bool _showRawLatex = false; // 🔥 新增：是否显示原始LaTeX代码

  @override
  void initState() {
    super.initState();
    
    // 🔥 智能选择默认模式
    final pdfExists = widget.document.pdfFilePath != null && 
                      File(widget.document.pdfFilePath!).existsSync();
    final mdExists = widget.document.markdownFilePath != null &&
                     File(widget.document.markdownFilePath!).existsSync();
    
    print('📱 阅读器初始化');
    print('   PDF存在: $pdfExists');
    print('   MD存在: $mdExists');
    
    if (mdExists) {
      _currentMode = ReadingMode.markdown;
      _loadMarkdownContent();
      print('   → 默认显示: Markdown');
    } else if (pdfExists) {
      _currentMode = ReadingMode.pdf;
      print('   → 默认显示: PDF');
    } else {
      print('   ⚠️ 两个文件都不存在');
    }
  }

  Future<void> _loadMarkdownContent() async {
    if (widget.document.markdownFilePath == null) return;

    setState(() => _isLoading = true);

    try {
      final file = File(widget.document.markdownFilePath!);
      final content = await file.readAsString();
      
      // 🔥 预处理 LaTeX 公式
      final processedContent = _preprocessLatex(content);
      
      setState(() {
        _markdownContent = processedContent;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 加载 Markdown 失败: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载 Markdown 失败: $e')),
      );
    }
  }

  /// 🔥 预处理 LaTeX 公式，将公式转换为可渲染的格式
  String _preprocessLatex(String content) {
    print('🔍 [LaTeX预处理] 开始处理内容，长度: ${content.length}');
    
    // 处理块级公式 ($$...$$)
    content = content.replaceAllMapped(
      RegExp(r'\$\$(.*?)\$\$', multiLine: true),
      (match) {
        final latexContent = match.group(1)?.trim() ?? '';
        // print('🔢 [LaTeX预处理] 块级公式: ${latexContent.substring(0, latexContent.length > 30 ? 30 : latexContent.length)}...');
        
        // 将 LaTeX 公式包装在特殊的标记中，稍后在渲染时处理
        return '\n\n<LATEX_BLOCK>$latexContent</LATEX_BLOCK>\n\n';
      },
    );
    
    // 处理行内公式 ($...$) - 更宽松的匹配
    content = content.replaceAllMapped(
      RegExp(r'\$([^$]+?)\$'),
      (match) {
        final latexContent = match.group(1)?.trim() ?? '';
        // print('🔢 [LaTeX预处理] 行内公式: ${latexContent.substring(0, latexContent.length > 20 ? 20 : latexContent.length)}...');
        
        // 将 LaTeX 公式包装在特殊的标记中
        return '<LATEX_INLINE>$latexContent</LATEX_INLINE>';
      },
    );
    
    // print('🔍 [LaTeX预处理] 处理完成，包含 LATEX_INLINE: ${content.contains('<LATEX_INLINE>')}');
    // print('🔍 [LaTeX预处理] 处理完成，包含 LATEX_BLOCK: ${content.contains('<LATEX_BLOCK>')}');
    
    return content;
  }

  /// 检查是否可以切换模式（两个文件都存在）
  bool _canSwitchMode() {
    final pdfExists = widget.document.pdfFilePath != null && 
                      File(widget.document.pdfFilePath!).existsSync();
    final mdExists = widget.document.markdownFilePath != null &&
                     File(widget.document.markdownFilePath!).existsSync();
    return pdfExists && mdExists;
  }

  void _switchMode() {
    setState(() {
      if (_currentMode == ReadingMode.pdf) {
        _currentMode = ReadingMode.markdown;
        if (_markdownContent == null) {
          _loadMarkdownContent();
        }
      } else {
        _currentMode = ReadingMode.pdf;
      }
    });
  }

  void _showDocumentInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('文档信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件名: ${widget.document.displayName}'),
            SizedBox(height: 8),
            Text('状态: ${widget.document.ocrStatus}'),
            SizedBox(height: 8),
            Text('文件大小: ${widget.document.formattedFileSize}'),
            SizedBox(height: 8),
            Text('上传时间: ${widget.document.uploadTime.toString().substring(0, 19)}'),
            if (widget.document.stats != null) ...[
              SizedBox(height: 8),
              Text('统计: ${widget.document.stats!.toString()}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.displayName),
        actions: [
          // 🔥 LaTeX显示模式切换按钮（仅在Markdown模式下显示）
          if (_currentMode == ReadingMode.markdown)
            IconButton(
              icon: Icon(
                _showRawLatex ? Icons.functions : Icons.code,
              ),
              tooltip: _showRawLatex ? '渲染LaTeX公式' : '显示原始LaTeX代码',
              onPressed: () {
                setState(() {
                  _showRawLatex = !_showRawLatex;
                });
              },
            ),
          
          // 🔥 只有当 Markdown 存在时才显示切换按钮
          if (_canSwitchMode())
            IconButton(
              icon: Icon(
                _currentMode == ReadingMode.pdf
                    ? Icons.article  // PDF 模式 → 显示文章图标（切换到 MD）
                    : Icons.picture_as_pdf,  // MD 模式 → 显示 PDF 图标
              ),
              tooltip: _currentMode == ReadingMode.pdf ? '文本模式' : 'PDF模式',
              onPressed: _switchMode,
            ),
          
          // 更多操作
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'share') {
                // TODO: 分享功能
              } else if (value == 'info') {
                _showDocumentInfo();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'info', child: Text('文档信息')),
              PopupMenuItem(value: 'share', child: Text('分享')),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_currentMode == ReadingMode.pdf) {
      return _buildPdfViewer();
    } else {
      return _buildMarkdownViewer();
    }
  }

  Widget _buildPdfViewer() {
    final pdfPath = widget.document.pdfFilePath;

    print('🔍 [PDF查看] 尝试打开 PDF');
    print('📂 [PDF路径] $pdfPath');
    
    if (pdfPath == null) {
      print('❌ [PDF路径] 路径为 null');
      return _buildErrorView('PDF 路径未设置');
    }

    final file = File(pdfPath);
    final exists = file.existsSync();
    
    print('📁 [文件检查] 文件存在: $exists');
    
    if (!exists) {
      print('❌ [文件检查] 文件不存在');
      return _buildErrorView('PDF 文件不存在\n路径: $pdfPath');
    }

    print('✅ [PDF查看] 文件存在，准备显示');
    
    // 🔥 使用新的 PDF 查看器组件
    return PdfViewerWidget(
      pdfPath: pdfPath,
      title: widget.document.displayName,
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          SizedBox(height: 16),
          // 不要删除文档！只显示错误
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('返回'),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownViewer() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_markdownContent == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Markdown 内容加载失败'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMarkdownContent,
              child: Text('重新加载'),
            ),
          ],
        ),
      );
    }

    return _buildCustomMarkdownViewer();
  }

  /// 🔥 自定义 Markdown 渲染器，支持 LaTeX 公式
  Widget _buildCustomMarkdownViewer() {
    final content = _markdownContent!;
    final lines = content.split('\n');
    final widgets = <Widget>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // 检查是否是 LaTeX 块级公式
      if (line.contains('<LATEX_BLOCK>') && line.contains('</LATEX_BLOCK>')) {
        final match = RegExp(r'<LATEX_BLOCK>(.*?)</LATEX_BLOCK>').firstMatch(line);
        if (match != null) {
          final latexContent = match.group(1)?.trim() ?? '';
          // print('🔢 [LaTeX渲染] 块级公式: ${latexContent.substring(0, latexContent.length > 30 ? 30 : latexContent.length)}...');
          
          widgets.add(
            Container(
              margin: EdgeInsets.symmetric(vertical: 16),
              child: _buildLatexWidget(latexContent, isBlock: true),
            ),
          );
        }
        continue;
      }
      
      // 检查是否是标题 (# ## ###)
      if (line.trim().startsWith('#')) {
        widgets.add(_buildTitleFromLine(line));
        continue;
      }
      
      // 检查是否包含图片
      if (line.contains('![') && line.contains('](') && line.contains(')')) {
        widgets.add(_buildImageFromLine(line));
        continue;
      }
      
      // 检查是否包含行内 LaTeX 公式
      if (line.contains('<LATEX_INLINE>')) {
        widgets.add(_buildTextWithInlineLatex(line));
        continue;
      }
      
      // 普通文本行
      if (line.trim().isNotEmpty) {
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              line,
              style: TextStyle(fontSize: 16, height: 1.6),
            ),
          ),
        );
      } else {
        widgets.add(SizedBox(height: 8));
      }
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  /// 🔥 构建包含行内 LaTeX 的文本
  Widget _buildTextWithInlineLatex(String text) {
    // 🔥 改进的行内LaTeX处理逻辑
    final regex = RegExp(r'<LATEX_INLINE>(.*?)</LATEX_INLINE>');
    final matches = regex.allMatches(text);
    
    if (matches.isEmpty) {
      // 没有LaTeX公式，直接返回普通文本
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: TextStyle(fontSize: 16, height: 1.6),
        ),
      );
    }
    
    final widgets = <Widget>[];
    int lastEnd = 0;
    
    for (final match in matches) {
      // 添加LaTeX公式前的普通文本
      if (match.start > lastEnd) {
        final beforeText = text.substring(lastEnd, match.start);
        if (beforeText.isNotEmpty) {
          widgets.add(
            Text(
              beforeText,
              style: TextStyle(fontSize: 16, height: 1.6),
            ),
          );
        }
      }
      
      // 添加LaTeX公式
      final latexContent = match.group(1)?.trim() ?? '';
      widgets.add(
        _buildLatexWidget(latexContent, isBlock: false),
      );
      
      lastEnd = match.end;
    }
    
    // 添加最后一个LaTeX公式后的普通文本
    if (lastEnd < text.length) {
      final afterText = text.substring(lastEnd);
      if (afterText.isNotEmpty) {
        widgets.add(
          Text(
            afterText,
            style: TextStyle(fontSize: 16, height: 1.6),
          ),
        );
      }
    }
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: widgets,
      ),
    );
  }

  /// 🔥 构建标题 Widget
  Widget _buildTitleFromLine(String line) {
    final trimmedLine = line.trim();
    int level = 0;
    while (level < trimmedLine.length && trimmedLine[level] == '#') {
      level++;
    }
    
    final titleText = trimmedLine.substring(level).trim();
    double fontSize;
    FontWeight fontWeight;
    
    switch (level) {
      case 1:
        fontSize = 24;
        fontWeight = FontWeight.bold;
        break;
      case 2:
        fontSize = 22;
        fontWeight = FontWeight.bold;
        break;
      case 3:
        fontSize = 20;
        fontWeight = FontWeight.bold;
        break;
      default:
        fontSize = 18;
        fontWeight = FontWeight.bold;
    }
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(
        titleText,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Colors.black87,
        ),
      ),
    );
  }

  /// 🔥 构建图片 Widget
  Widget _buildImageFromLine(String line) {
    final match = RegExp(r'!\[.*?\]\((.*?)\)').firstMatch(line);
    if (match == null) return SizedBox.shrink();
    
    final imagePath = match.group(1) ?? '';
    // print('🖼️ [图片] 加载: $imagePath');
    
    // 构建完整路径
    String fullPath;
    if (imagePath.startsWith('/')) {
      fullPath = imagePath;
    } else {
      final imagesDir = widget.document.imagesDirectoryPath;
      if (imagesDir != null) {
        final jobDir = Directory(imagesDir).parent.path;
        fullPath = '$jobDir/$imagePath';
      } else {
        print('❌ [图片] images目录路径为null');
        return Column(
          children: [
            Icon(Icons.broken_image, size: 50, color: Colors.grey),
            Text('图片目录未设置', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        );
      }
    }
    
    print('📂 [图片] 完整路径: $fullPath');
    
    final file = File(fullPath);
    if (!file.existsSync()) {
      print('❌ [图片] 文件不存在: $fullPath');
      return Column(
        children: [
          Icon(Icons.broken_image, size: 50, color: Colors.grey),
          Text('图片加载失败', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      );
    }
    
    print('✅ [图片] 文件存在，准备显示');
    
    return GestureDetector(
      onTap: () {
        // 点击图片放大查看
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Image.file(file),
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        child: Image.file(
          file,
          fit: BoxFit.contain,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            print('❌ [图片] 加载错误: $error');
            return Column(
              children: [
                Icon(Icons.error, size: 50, color: Colors.red),
                Text('图片加载错误', style: TextStyle(fontSize: 12, color: Colors.red)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 🔥 构建 LaTeX 公式 Widget
  Widget _buildLatexWidget(String latexContent, {required bool isBlock}) {
    // 🔥 如果启用原始LaTeX显示模式，直接显示代码
    if (_showRawLatex) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: isBlock ? 8 : 2),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100], // 使用更中性的灰色
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey[400]!, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBlock ? '块级公式' : '行内公式',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600], // 使用灰色而不是蓝色
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              latexContent,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black, // 使用黑色
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }
    
    try {
      // 🔥 最简化的LaTeX渲染策略
      return Padding(
        padding: EdgeInsets.symmetric(vertical: isBlock ? 8 : 2),
        child: Math.tex(
          latexContent,
          textStyle: TextStyle(
            fontSize: isBlock ? 18 : 16, // 增大字体以提高可读性
            color: Colors.black, // 纯黑色
          ),
          mathStyle: isBlock ? MathStyle.display : MathStyle.text,
          onErrorFallback: (error) {
            print('❌ [LaTeX] 渲染失败: $error');
            return Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                'LaTeX错误: ${latexContent.length > 30 ? latexContent.substring(0, 30) + '...' : latexContent}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[700],
                  fontFamily: 'monospace',
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      print('❌ [LaTeX] 渲染异常: $e');
      return Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '公式渲染异常',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              latexContent.length > 50 
                  ? '${latexContent.substring(0, 50)}...'
                  : latexContent,
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange[600],
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }
  }

  /// 🔥 原始 Markdown 渲染器（备用）
  Widget _buildOriginalMarkdownViewer() {
    return Markdown(
      data: _markdownContent!,
      selectable: true,
      // 🔥 使用自定义图片构建器解决路径问题
      imageBuilder: (Uri uri, String? title, String? alt) {
        print('🖼️ [图片] 加载: ${uri.path}');
        
        // Markdown中的路径是相对路径：images/xxx.jpg
        final imagePath = uri.path;
        
        // 构建完整路径
        String fullPath;
        if (imagePath.startsWith('/')) {
          // 绝对路径，直接使用
          fullPath = imagePath;
        } else {
          // 相对路径，需要拼接
          final imagesDir = widget.document.imagesDirectoryPath;
          if (imagesDir != null) {
            // 🔥 关键：获取job_id目录，不要拼接images
            final jobDir = Directory(imagesDir).parent.path;
            fullPath = '$jobDir/$imagePath';
          } else {
            print('❌ [图片] images目录路径为null');
            return Column(
              children: [
                Icon(Icons.broken_image, size: 50, color: Colors.grey),
                Text('图片目录未设置', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            );
          }
        }
        
        print('📂 [图片] 完整路径: $fullPath');
        
        final file = File(fullPath);
        if (!file.existsSync()) {
          print('❌ [图片] 文件不存在: $fullPath');
          return Column(
            children: [
              Icon(Icons.broken_image, size: 50, color: Colors.grey),
              Text('图片加载失败', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          );
        }
        
        print('✅ [图片] 文件存在，准备显示');
        
        return GestureDetector(
          onTap: () {
            // 点击图片放大查看
            showDialog(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: Colors.transparent,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Image.file(file),
                ),
              ),
            );
          },
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            child: Image.file(
              file,
              fit: BoxFit.contain,
              width: double.infinity,  // 占满宽度
              errorBuilder: (context, error, stackTrace) {
                print('❌ [图片] 加载错误: $error');
                return Column(
                  children: [
                    Icon(Icons.error, size: 50, color: Colors.red),
                    Text('图片加载错误', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ],
                );
              },
            ),
          ),
        );
      },
      // 🔥 自定义构建器用于渲染LaTeX公式 (暂时禁用以修复编译错误)
      // builders: _latexBuilder(),
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 16, height: 1.6),
        h1: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        h2: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        h3: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        code: TextStyle(
          backgroundColor: Colors.grey[200],
          fontFamily: 'monospace',
          fontSize: 14,
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        // 🔥 图片样式
        img: TextStyle(fontSize: 14),  // 图片说明文字
        blockSpacing: 16.0,  // 块之间的间距
      ),
    );
  }

  /*
  /// 🔥 创建LaTeX公式渲染构建器 (暂时禁用以修复编译错误)
  Map<String, MarkdownElementBuilder> _latexBuilder() {
    return {
      'code': (BuildContext context, element) {
        final text = element.textContent;
        
        // 检查是否是LaTeX公式（行内公式或块级公式）
        final isInlineLatex = text.startsWith(r'$') && text.endsWith(r'$') && text.length > 2;
        final isBlockLatex = text.startsWith(r'$$') && text.endsWith(r'$$') && text.length > 4;
        
        if (isInlineLatex || isBlockLatex) {
          // 提取LaTeX内容
          final latexContent = isInlineLatex 
              ? text.substring(1, text.length - 1)
              : text.substring(2, text.length - 2);
          
          print('🔢 [LaTeX] 渲染公式: ${latexContent.substring(0, latexContent.length > 30 ? 30 : latexContent.length)}...');
          
          try {
            return Container(
              margin: isBlockLatex 
                  ? EdgeInsets.symmetric(vertical: 16)  // 块级公式有更多间距
                  : EdgeInsets.symmetric(horizontal: 4),  // 行内公式紧凑间距
              child: Math.tex(
                latexContent,
                textStyle: TextStyle(
                  fontSize: isBlockLatex ? 18 : 16,  // 块级公式稍大
                  color: Colors.black87,
                ),
                mathStyle: MathStyle.display,  // 显示模式
                onErrorFallback: (error) {
                  print('❌ [LaTeX] 渲染失败: $error');
                  return Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(
                      'LaTeX错误: $latexContent',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
            );
          } catch (e) {
            print('❌ [LaTeX] 渲染异常: $e');
            return Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange),
              ),
              child: Text(
                '公式: $latexContent',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange[800],
                  fontFamily: 'monospace',
                ),
              ),
            );
          }
        }
        
        // 如果不是LaTeX公式，使用默认的代码渲染
        return Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
        );
      },
    };
  }
  */
}
