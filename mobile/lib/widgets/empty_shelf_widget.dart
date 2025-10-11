import 'package:flutter/material.dart';

/// 空状态书架组件
class EmptyShelfWidget extends StatefulWidget {
  final VoidCallback? onAddPressed;
  final String? customMessage;
  final String? customSubMessage;

  const EmptyShelfWidget({
    super.key,
    this.onAddPressed,
    this.customMessage,
    this.customSubMessage,
  });

  @override
  State<EmptyShelfWidget> createState() => _EmptyShelfWidgetState();
}

class _EmptyShelfWidgetState extends State<EmptyShelfWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _bounceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _bounceAnimation = CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    );

    // 启动动画
    _fadeController.forward();
    _bounceController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 空书架插图
              ScaleTransition(
                scale: _bounceAnimation,
                child: _buildEmptyShelfIllustration(context),
              ),
              
              const SizedBox(height: 32),
              
              // 主标题
              Text(
                widget.customMessage ?? '书架上还没有书',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // 副标题
              Text(
                widget.customSubMessage ?? '点击添加按钮，添加您的第一本PDF！',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // 添加按钮
              if (widget.onAddPressed != null)
                ScaleTransition(
                  scale: _bounceAnimation,
                  child: FilledButton.icon(
                    onPressed: widget.onAddPressed,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('添加PDF文件'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // 提示信息卡片
              _buildTipsCard(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建空书架插图
  Widget _buildEmptyShelfIllustration(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 200,
      height: 160,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // 书架背景
          Positioned.fill(
            child: CustomPaint(
              painter: _BookshelfPainter(
                shelfColor: colorScheme.outline.withValues(alpha: 0.3),
                backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
              ),
            ),
          ),
          
          // 中央的书本图标
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_outlined,
                size: 48,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建提示信息卡片
  Widget _buildTipsCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '使用提示',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              context,
              Icons.touch_app,
              '点击卡片打开阅读',
            ),
            _buildTipItem(
              context,
              Icons.favorite_border,
              '点击心形图标收藏',
            ),
            _buildTipItem(
              context,
              Icons.select_all,
              '长按卡片进入多选模式',
            ),
          ],
        ),
      ),
    );
  }

  /// 构建提示项
  Widget _buildTipItem(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 书架自定义绘制器
class _BookshelfPainter extends CustomPainter {
  final Color shelfColor;
  final Color backgroundColor;

  _BookshelfPainter({
    required this.shelfColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = shelfColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    // 绘制背景
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(20),
      ),
      backgroundPaint,
    );

    // 绘制书架横线
    final shelfY1 = size.height * 0.3;
    final shelfY2 = size.height * 0.6;
    final shelfY3 = size.height * 0.9;

    canvas.drawLine(
      Offset(size.width * 0.1, shelfY1),
      Offset(size.width * 0.9, shelfY1),
      paint,
    );

    canvas.drawLine(
      Offset(size.width * 0.1, shelfY2),
      Offset(size.width * 0.9, shelfY2),
      paint,
    );

    canvas.drawLine(
      Offset(size.width * 0.1, shelfY3),
      Offset(size.width * 0.9, shelfY3),
      paint,
    );

    // 绘制书架两侧
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.1),
      Offset(size.width * 0.1, size.height * 0.9),
      paint,
    );

    canvas.drawLine(
      Offset(size.width * 0.9, size.height * 0.1),
      Offset(size.width * 0.9, size.height * 0.9),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 搜索结果为空的组件
class EmptySearchResultWidget extends StatelessWidget {
  final String searchQuery;
  final VoidCallback? onClearSearch;

  const EmptySearchResultWidget({
    super.key,
    required this.searchQuery,
    this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              '未找到相关结果',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '没有找到包含"$searchQuery"的PDF文件',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (onClearSearch != null)
              OutlinedButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.clear),
                label: const Text('清除搜索'),
              ),
          ],
        ),
      ),
    );
  }
}
