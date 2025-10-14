/// API 配置管理
class ApiConfig {
  /// 开发环境服务器地址
  /// 注意：Android 模拟器使用 10.0.2.2 访问本地主机
  /// iOS 模拟器和真机可以使用 localhost
  static const String devBaseUrl = 'http://10.0.2.2:8000';

  /// 生产环境服务器地址（待配置）
  static const String prodBaseUrl = 'https://your-production-server.com';

  /// API 前缀
  static const String apiPrefix = '/api/v1';

  /// 当前环境
  static const Environment currentEnvironment = Environment.development;

  /// 获取基础 URL
  static String get baseUrl {
    switch (currentEnvironment) {
      case Environment.development:
        return devBaseUrl;
      case Environment.production:
        return prodBaseUrl;
    }
  }

  /// 获取完整的 API URL
  static String getApiUrl(String endpoint) {
    return '$baseUrl$apiPrefix$endpoint';
  }

  /// 请求超时时间（秒）
  static const int requestTimeout = 30;

  /// 上传超时时间（秒）- 文件上传需要更长时间
  static const int uploadTimeout = 300;

  /// 下载超时时间（秒）- 文件下载需要更长时间
  static const int downloadTimeout = 300;

  /// 是否启用请求日志
  static const bool enableLogging = true;

  /// 最大重试次数
  static const int maxRetries = 3;

  /// 重试间隔（毫秒）
  static const int retryInterval = 1000;
}

/// 环境枚举
enum Environment {
  development,
  production,
}

/// API 端点常量
class ApiEndpoints {
  /// OCR 相关端点
  static const String uploadPdf = '/ocr/upload';
  static const String startProcessing = '/ocr/process';
  static const String getStatus = '/ocr/status';
  static const String downloadResult = '/ocr/download';
  static const String downloadZip = '/ocr/download-zip';
  static const String cleanup = '/ocr/cleanup';

  /// 获取完整的端点 URL
  static String getUploadUrl() => ApiConfig.getApiUrl(uploadPdf);
  static String getStartProcessingUrl() => ApiConfig.getApiUrl(startProcessing);
  static String getStatusUrl(String jobId) => ApiConfig.getApiUrl('$getStatus/$jobId');
  static String getDownloadUrl(String jobId) => ApiConfig.getApiUrl('$downloadResult/$jobId');
  static String getDownloadZipUrl(String jobId) => ApiConfig.getApiUrl('$downloadZip/$jobId');
  static String getCleanupUrl(String jobId) => ApiConfig.getApiUrl('$cleanup/$jobId');
}
