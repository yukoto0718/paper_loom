import 'dart:io';
import 'package:dio/dio.dart';
import 'api_config.dart';
import '../models/api_response.dart';

/// 基础网络服务类
/// 
/// 封装通用的网络请求逻辑，包括错误处理、重试机制等
class BaseApiService {
  late Dio _dio;

  BaseApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: Duration(seconds: ApiConfig.requestTimeout),
      receiveTimeout: Duration(seconds: ApiConfig.requestTimeout),
      sendTimeout: Duration(seconds: ApiConfig.requestTimeout),
    ));

    // 添加日志拦截器（仅在开发环境启用）
    if (ApiConfig.enableLogging) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (log) => print('[DIO] $log'),
      ));
    }

    // 添加重试拦截器
    _dio.interceptors.add(RetryInterceptor(
      dio: _dio,
      maxRetries: ApiConfig.maxRetries,
      retryInterval: ApiConfig.retryInterval,
    ));
  }

  /// 发送 GET 请求
  Future<ApiResponse<T>> get<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic>)? dataParser,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: queryParameters,
      );

      return ApiResponse<T>.fromJson(
        response.data!,
        dataParser,
      );
    } catch (error) {
      return _handleError<T>(error);
    }
  }

  /// 发送 POST 请求
  Future<ApiResponse<T>> post<T>(
    String url, {
    dynamic data,
    T Function(Map<String, dynamic>)? dataParser,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: data,
      );

      return ApiResponse<T>.fromJson(
        response.data!,
        dataParser,
      );
    } catch (error) {
      return _handleError<T>(error);
    }
  }

  /// 发送文件上传请求
  Future<ApiResponse<T>> upload<T>(
    String url, {
    required File file,
    required String fieldName,
    Map<String, dynamic>? formData,
    ProgressCallback? onProgress,
    T Function(Map<String, dynamic>)? dataParser,
  }) async {
    try {
      final fileName = file.path.split('/').last;
      final formDataMap = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
        ...?formData,
      });

      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: formDataMap,
        onSendProgress: onProgress,
        options: Options(
          sendTimeout: Duration(seconds: ApiConfig.uploadTimeout),
        ),
      );

      return ApiResponse<T>.fromJson(
        response.data!,
        dataParser,
      );
    } catch (error) {
      return _handleError<T>(error);
    }
  }

  /// 下载文件
  Future<String> download(
    String url,
    String savePath, {
    ProgressCallback? onProgress,
  }) async {
    try {
      final response = await _dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
        options: Options(
          receiveTimeout: Duration(seconds: ApiConfig.downloadTimeout),
        ),
      );

      if (response.statusCode == 200) {
        return savePath;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: '下载失败，状态码: ${response.statusCode}',
        );
      }
    } catch (error) {
      throw _handleDownloadError(error);
    }
  }

  /// 处理错误
  ApiResponse<T> _handleError<T>(dynamic error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final errorData = error.response?.data;

      // 解析后端返回的错误信息
      if (errorData is Map<String, dynamic> && errorData.containsKey('error')) {
        final apiError = ApiError.fromJson(errorData['error']);
        return ApiResponse<T>.failure(
          message: apiError.description,
          error: apiError,
        );
      }

      // 处理网络错误
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ApiResponse<T>.failure(
            message: '网络连接超时，请检查网络后重试',
            error: ApiError(
              code: 'NETWORK_TIMEOUT',
              details: '请求超时',
            ),
          );
        case DioExceptionType.badResponse:
          return ApiResponse<T>.failure(
            message: _getErrorMessageFromStatusCode(statusCode),
            error: ApiError(
              code: 'HTTP_$statusCode',
              details: errorData?.toString() ?? '服务器错误',
            ),
          );
        case DioExceptionType.cancel:
          return ApiResponse<T>.failure(
            message: '请求已取消',
            error: ApiError(
              code: 'REQUEST_CANCELLED',
              details: '用户取消了请求',
            ),
          );
        case DioExceptionType.unknown:
          if (error.error is SocketException) {
            return ApiResponse<T>.failure(
              message: '网络连接失败，请检查网络设置',
              error: ApiError(
                code: 'NETWORK_ERROR',
                details: '无法连接到服务器',
              ),
            );
          }
          return ApiResponse<T>.failure(
            message: '网络请求失败: ${error.message}',
            error: ApiError(
              code: 'UNKNOWN_ERROR',
              details: error.toString(),
            ),
          );
        default:
          return ApiResponse<T>.failure(
            message: '网络请求失败',
            error: ApiError(
              code: 'UNKNOWN_ERROR',
              details: error.toString(),
            ),
          );
      }
    }

    // 处理其他类型的错误
    return ApiResponse<T>.failure(
      message: '未知错误: $error',
      error: ApiError(
        code: 'UNKNOWN_ERROR',
        details: error.toString(),
      ),
    );
  }

  /// 处理下载错误
  Exception _handleDownloadError(dynamic error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      return Exception(_getErrorMessageFromStatusCode(statusCode));
    }
    return Exception('下载失败: $error');
  }

  /// 根据状态码获取错误消息
  String _getErrorMessageFromStatusCode(int? statusCode) {
    switch (statusCode) {
      case 400:
        return '请求参数错误';
      case 401:
        return '未授权访问';
      case 403:
        return '访问被拒绝';
      case 404:
        return '请求的资源不存在';
      case 413:
        return '文件大小超过限制';
      case 500:
        return '服务器内部错误';
      case 502:
        return '网关错误';
      case 503:
        return '服务不可用';
      default:
        return '网络请求失败 (状态码: $statusCode)';
    }
  }
}

/// 重试拦截器
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final int retryInterval;

  RetryInterceptor({
    required this.dio,
    required this.maxRetries,
    required this.retryInterval,
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final retryCount = options.extra['retry_count'] ?? 0;

    // 只对特定错误进行重试
    if (_shouldRetry(err) && retryCount < maxRetries) {
      await Future.delayed(Duration(milliseconds: retryInterval));

      // 更新重试计数
      options.extra['retry_count'] = retryCount + 1;

      try {
        // 重新发送请求
        final response = await dio.fetch(options);
        handler.resolve(response);
      } catch (retryError) {
        handler.reject(retryError as DioException);
      }
    } else {
      handler.reject(err);
    }
  }

  /// 判断是否应该重试
  bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        (error.type == DioExceptionType.badResponse &&
            error.response?.statusCode != null &&
            error.response!.statusCode! >= 500);
  }
}
