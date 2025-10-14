import 'package:flutter/material.dart';
import '../models/pdf_document.dart';

/// PDF书本卡片组件
class PDFBookCard extends StatefulWidget {
  final PDFDocument document;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleSelection;
  final VoidCallback? onToggleFavorite;

  const PDFBookCard({
    super.key,
    required this.document,
    this.isSelected = false,
    this.isMultiSelectMode = false,
    this.onTap,
    this.onLongPress,
    this.onToggleSelection,
    this.onToggleFavorite,
  });

  @override
  State<PDFBookCard> createState() => _PDFBookCardState();
}

class _PDFBookCardState extends State<PDFBookCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: widget.isMultiSelectMode ? widget.onToggleSelection : widget.onTap,
            onLongPress: widget.onLongPress,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: widget.isSelected
                    ? Border.all(
                        color: colorScheme.primary,
                        width: 3,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: colorScheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PDF封面区域
                      Expanded(
                        flex: 4,
                        child: _buildCoverArea(context),
                      ),
                      // 文件信息区域
                      Expanded(
                        flex: 2,
                        child: _buildInfoArea(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建封面区域
  Widget _buildCoverArea(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Stack(
        children: [
          // PDF图标背景
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.picture_as_pdf,
                size: 48,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          
          // 选择状态覆盖层
          if (widget.isMultiSelectMode)
            Positioned(
              top: 8,
              left: 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.isSelected 
                      ? colorScheme.primary 
                      : colorScheme.surface.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: widget.isSelected 
                      ? null 
                      : Border.all(color: colorScheme.outline),
                ),
                child: Icon(
                  widget.isSelected ? Icons.check : null,
                  size: 16,
                  color: widget.isSelected 
                      ? colorScheme.onPrimary 
                      : null,
                ),
              ),
            ),
          
          // 收藏图标
          if (widget.document.isFavorite)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: widget.onToggleFavorite,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          
          // 阅读进度指示器
          if (widget.document.progress > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: widget.document.progress,
                backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  colorScheme.primary,
                ),
                minHeight: 3,
              ),
            ),
        ],
      ),
    );
  }

  /// 构建信息区域
  Widget _buildInfoArea(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 文件名
          Expanded(
            child: Text(
              widget.document.fileName,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // 阅读进度和页数信息
          Row(
            children: [
              Expanded(
                child: Text(
                  '第${widget.document.currentPage}页',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                widget.document.progressPercentage,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 2),
          
          // 文件大小和书签数量
          Row(
            children: [
              Icon(
                Icons.insert_drive_file,
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.document.formattedFileSize,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (widget.document.bookmarks.isNotEmpty) ...[
                Icon(
                  Icons.bookmark,
                  size: 12,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 2),
                Text(
                  '${widget.document.bookmarks.length}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// PDF书本网格视图组件
class PDFBookGrid extends StatelessWidget {
  final List<PDFDocument> documents;
  final bool isMultiSelectMode;
  final Set<String> selectedDocuments;
  final Function(PDFDocument) onDocumentTap;
  final Function(PDFDocument) onDocumentLongPress;
  final Function(PDFDocument) onToggleSelection;
  final Function(PDFDocument) onToggleFavorite;

  const PDFBookGrid({
    super.key,
    required this.documents,
    required this.isMultiSelectMode,
    required this.selectedDocuments,
    required this.onDocumentTap,
    required this.onDocumentLongPress,
    required this.onToggleSelection,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7, // 调整宽高比，使卡片更像书本
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final document = documents[index];
        final isSelected = selectedDocuments.contains(document.filePath);

        return PDFBookCard(
          document: document,
          isSelected: isSelected,
          isMultiSelectMode: isMultiSelectMode,
          onTap: () => onDocumentTap(document),
          onLongPress: () => onDocumentLongPress(document),
          onToggleSelection: () => onToggleSelection(document),
          onToggleFavorite: () => onToggleFavorite(document),
        );
      },
    );
  }
}
