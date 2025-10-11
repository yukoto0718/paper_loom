/// PDF文档数据模型
/// 
/// 包含PDF文档的基本信息和阅读进度
class PDFDocument {
  /// 文件路径
  final String filePath;
  
  /// 文件名（不含路径）
  final String fileName;
  
  /// 文件大小（字节）
  final int fileSize;
  
  /// 总页数
  final int totalPages;
  
  /// 当前页面（从1开始）
  int currentPage;
  
  /// 阅读进度（0.0 - 1.0）
  double get progress => totalPages > 0 ? currentPage / totalPages : 0.0;
  
  /// 最后阅读时间
  DateTime lastReadTime;
  
  /// 缩放级别
  double zoomLevel;
  
  /// 是否收藏
  bool isFavorite;
  
  /// 书签页面列表
  List<int> bookmarks;

  PDFDocument({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.totalPages,
    this.currentPage = 1,
    DateTime? lastReadTime,
    this.zoomLevel = 1.0,
    this.isFavorite = false,
    List<int>? bookmarks,
  }) : 
    lastReadTime = lastReadTime ?? DateTime.now(),
    bookmarks = bookmarks ?? [];

  /// 从JSON创建PDFDocument对象
  factory PDFDocument.fromJson(Map<String, dynamic> json) {
    return PDFDocument(
      filePath: json['filePath'] as String,
      fileName: json['fileName'] as String,
      fileSize: json['fileSize'] as int,
      totalPages: json['totalPages'] as int,
      currentPage: json['currentPage'] as int? ?? 1,
      lastReadTime: DateTime.parse(json['lastReadTime'] as String),
      zoomLevel: (json['zoomLevel'] as num?)?.toDouble() ?? 1.0,
      isFavorite: json['isFavorite'] as bool? ?? false,
      bookmarks: (json['bookmarks'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList() ?? [],
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'fileName': fileName,
      'fileSize': fileSize,
      'totalPages': totalPages,
      'currentPage': currentPage,
      'lastReadTime': lastReadTime.toIso8601String(),
      'zoomLevel': zoomLevel,
      'isFavorite': isFavorite,
      'bookmarks': bookmarks,
    };
  }

  /// 复制对象并修改部分属性
  PDFDocument copyWith({
    String? filePath,
    String? fileName,
    int? fileSize,
    int? totalPages,
    int? currentPage,
    DateTime? lastReadTime,
    double? zoomLevel,
    bool? isFavorite,
    List<int>? bookmarks,
  }) {
    return PDFDocument(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      isFavorite: isFavorite ?? this.isFavorite,
      bookmarks: bookmarks ?? List<int>.from(this.bookmarks),
    );
  }

  /// 添加书签
  void addBookmark(int pageNumber) {
    if (!bookmarks.contains(pageNumber) && pageNumber > 0 && pageNumber <= totalPages) {
      bookmarks.add(pageNumber);
      bookmarks.sort();
    }
  }

  /// 移除书签
  void removeBookmark(int pageNumber) {
    bookmarks.remove(pageNumber);
  }

  /// 检查是否有书签
  bool hasBookmark(int pageNumber) {
    return bookmarks.contains(pageNumber);
  }

  /// 跳转到页面
  void goToPage(int pageNumber) {
    if (pageNumber >= 1 && pageNumber <= totalPages) {
      currentPage = pageNumber;
      lastReadTime = DateTime.now();
    }
  }

  /// 下一页
  bool nextPage() {
    if (currentPage < totalPages) {
      currentPage++;
      lastReadTime = DateTime.now();
      return true;
    }
    return false;
  }

  /// 上一页
  bool previousPage() {
    if (currentPage > 1) {
      currentPage--;
      lastReadTime = DateTime.now();
      return true;
    }
    return false;
  }

  /// 设置缩放级别
  void setZoomLevel(double zoom) {
    if (zoom >= 0.5 && zoom <= 3.0) {
      zoomLevel = zoom;
    }
  }

  /// 获取文件大小的可读格式
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// 获取阅读进度百分比
  String get progressPercentage {
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  @override
  String toString() {
    return 'PDFDocument(fileName: $fileName, currentPage: $currentPage/$totalPages, progress: $progressPercentage)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PDFDocument && other.filePath == filePath;
  }

  @override
  int get hashCode => filePath.hashCode;
}
