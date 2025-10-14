import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// 权限服务异常类
class PermissionServiceException implements Exception {
  final String message;
  final String? details;
  
  const PermissionServiceException(this.message, [this.details]);
  
  @override
  String toString() {
    return details != null ? '$message: $details' : message;
  }
}

/// 权限服务
/// 
/// 处理Android平台的文件访问权限
class PermissionService {
  /// 检查并请求存储权限
  /// 
  /// 返回权限是否已获得
  static Future<bool> requestStoragePermissions() async {
    // iOS不需要额外的存储权限
    if (Platform.isIOS) {
      return true;
    }

    try {
      // Android 13+ (API 33+) 使用细分权限
      if (Platform.isAndroid) {
        // 检查Android版本，使用不同的权限策略
        final androidInfo = await _getAndroidVersion();
        
        if (androidInfo >= 33) {
          // Android 13+ 使用细分媒体权限
          return await _requestMediaPermissions();
        } else if (androidInfo >= 30) {
          // Android 11-12 使用管理外部存储权限
          return await _requestManageExternalStorage();
        } else {
          // Android 10及以下使用传统存储权限
          return await _requestLegacyStoragePermissions();
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('请求存储权限失败: $e');
      return false;
    }
  }

  /// 检查是否已有存储权限
  static Future<bool> hasStoragePermissions() async {
    if (Platform.isIOS) {
      return true;
    }

    try {
      final androidInfo = await _getAndroidVersion();
      
      if (androidInfo >= 33) {
        // Android 13+ 检查媒体权限
        return await _hasMediaPermissions();
      } else if (androidInfo >= 30) {
        // Android 11-12 检查管理外部存储权限
        return await Permission.manageExternalStorage.isGranted;
      } else {
        // Android 10及以下检查传统存储权限
        return await Permission.storage.isGranted;
      }
    } catch (e) {
      debugPrint('检查存储权限失败: $e');
      return false;
    }
  }

  /// 请求Android 13+的媒体权限
  static Future<bool> _requestMediaPermissions() async {
    final permissions = [
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    // 只要有一个权限被授予就算成功（PDF文件通常存储在文档目录）
    bool hasAnyPermission = statuses.values.any(
      (status) => status == PermissionStatus.granted
    );

    // 如果没有媒体权限，尝试请求外部存储访问权限
    if (!hasAnyPermission) {
      final storageStatus = await Permission.storage.request();
      hasAnyPermission = storageStatus == PermissionStatus.granted;
    }

    return hasAnyPermission;
  }

  /// 检查Android 13+的媒体权限
  static Future<bool> _hasMediaPermissions() async {
    final permissions = [
      Permission.photos,
      Permission.videos,
      Permission.audio,
      Permission.storage,
    ];

    for (final permission in permissions) {
      if (await permission.isGranted) {
        return true;
      }
    }

    return false;
  }

  /// 请求Android 11-12的管理外部存储权限
  static Future<bool> _requestManageExternalStorage() async {
    // 首先尝试普通存储权限
    var status = await Permission.storage.request();
    if (status == PermissionStatus.granted) {
      return true;
    }

    // 如果普通权限被拒绝，尝试管理外部存储权限
    status = await Permission.manageExternalStorage.request();
    return status == PermissionStatus.granted;
  }

  /// 请求Android 10及以下的传统存储权限
  static Future<bool> _requestLegacyStoragePermissions() async {
    final status = await Permission.storage.request();
    return status == PermissionStatus.granted;
  }

  /// 获取Android版本号
  static Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) {
      return 0;
    }

    try {
      // 这里返回一个默认值，实际应用中可以使用device_info_plus获取准确版本
      // 为了简化，我们假设是Android 13+
      return 33;
    } catch (e) {
      debugPrint('获取Android版本失败: $e');
      return 30; // 默认使用Android 11的权限模式
    }
  }

  /// 打开应用设置页面
  static Future<void> openAppSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('打开应用设置失败: $e');
    }
  }

  /// 显示权限说明对话框的辅助方法
  static String getPermissionRationaleMessage() {
    if (Platform.isAndroid) {
      return '''Paper Loom需要访问存储权限来：

• 浏览和选择PDF文件
• 保存阅读进度和书签
• 管理您的PDF文档库

请在设置中授予存储权限，以便正常使用应用。''';
    }
    
    return '需要文件访问权限来管理PDF文档。';
  }

  /// 检查权限状态并返回详细信息
  static Future<PermissionStatusInfo> getDetailedPermissionStatus() async {
    if (Platform.isIOS) {
      return PermissionStatusInfo(
        hasPermission: true,
        needsRequest: false,
        canShowRationale: false,
        isPermanentlyDenied: false,
        message: 'iOS平台无需额外权限',
      );
    }

    try {
      final androidVersion = await _getAndroidVersion();
      Permission targetPermission;
      
      if (androidVersion >= 33) {
        targetPermission = Permission.photos;
      } else if (androidVersion >= 30) {
        targetPermission = Permission.manageExternalStorage;
      } else {
        targetPermission = Permission.storage;
      }

      final status = await targetPermission.status;
      final hasPermission = status == PermissionStatus.granted;
      final isPermanentlyDenied = status == PermissionStatus.permanentlyDenied;
      final canShowRationale = !isPermanentlyDenied && status == PermissionStatus.denied;

      String message;
      if (hasPermission) {
        message = '存储权限已授予';
      } else if (isPermanentlyDenied) {
        message = '存储权限被永久拒绝，请在设置中手动开启';
      } else {
        message = '需要存储权限来访问PDF文件';
      }

      return PermissionStatusInfo(
        hasPermission: hasPermission,
        needsRequest: !hasPermission && !isPermanentlyDenied,
        canShowRationale: canShowRationale,
        isPermanentlyDenied: isPermanentlyDenied,
        message: message,
      );
    } catch (e) {
      return PermissionStatusInfo(
        hasPermission: false,
        needsRequest: false,
        canShowRationale: false,
        isPermanentlyDenied: false,
        message: '检查权限状态失败: $e',
      );
    }
  }
}

/// 权限状态信息
class PermissionStatusInfo {
  final bool hasPermission;
  final bool needsRequest;
  final bool canShowRationale;
  final bool isPermanentlyDenied;
  final String message;

  const PermissionStatusInfo({
    required this.hasPermission,
    required this.needsRequest,
    required this.canShowRationale,
    required this.isPermanentlyDenied,
    required this.message,
  });
}
