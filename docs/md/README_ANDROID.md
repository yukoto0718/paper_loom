# Paper Loom Android 配置说明

本文档说明了Paper Loom PDF阅读器应用的Android端配置和优化。

## 📱 Android 配置概述

### 系统要求
- **最低Android版本**: Android 5.0 (API 21)
- **目标Android版本**: Android 14 (API 34)
- **编译SDK版本**: 34

### 主要功能支持
✅ PDF文件选择和阅读  
✅ 文件权限管理  
✅ 跨Android版本兼容  
✅ 阅读进度保存  
✅ 书签和收藏功能  

## 🔧 技术配置

### 1. Gradle 配置
```kotlin
// android/app/build.gradle.kts
android {
    compileSdk = 34
    defaultConfig {
        minSdk = 21
        targetSdk = 34
    }
}
```

### 2. 权限配置
应用已配置以下权限以支持不同Android版本：

#### Android 13+ (API 33+)
- `READ_MEDIA_IMAGES`
- `READ_MEDIA_VIDEO` 
- `READ_MEDIA_AUDIO`

#### Android 11-12 (API 30-32)
- `READ_EXTERNAL_STORAGE`
- `MANAGE_EXTERNAL_STORAGE`

#### Android 10及以下 (API ≤29)
- `READ_EXTERNAL_STORAGE`
- `WRITE_EXTERNAL_STORAGE`

### 3. 应用配置
- ✅ 启用硬件加速
- ✅ 支持传统外部存储访问
- ✅ 网络安全配置
- ✅ 应用备份支持

## 🛠️ 开发和调试

### 运行调试版本
```bash
flutter run -d android
```

### 构建发布版本
```bash
flutter build apk --release
```

### 构建App Bundle (推荐)
```bash
flutter build appbundle --release
```

## 📋 权限处理

### 智能权限管理
应用使用`PermissionService`智能处理不同Android版本的权限：

1. **自动检测Android版本**
2. **请求相应权限**
3. **处理权限拒绝情况**
4. **引导用户到设置页面**

### 权限申请流程
1. 检查当前权限状态
2. 根据Android版本选择合适的权限
3. 显示权限说明（如需要）
4. 请求权限
5. 处理用户响应

## 🔒 安全性

### ProGuard 规则
已配置必要的ProGuard规则保护：
- Flutter框架
- PDF渲染库
- 文件选择器
- 路径提供器
- 偏好设置

### 网络安全
- 支持HTTPS通信
- 开发模式允许HTTP（仅调试）

## 📦 依赖管理

### 核心依赖
```yaml
dependencies:
  flutter_pdfview: ^1.3.2      # PDF渲染
  file_picker: ^6.1.1          # 文件选择
  path_provider: ^2.1.1        # 路径管理
  shared_preferences: ^2.2.2   # 数据存储
  permission_handler: ^11.3.1  # 权限管理
```

## 🚀 部署准备

### 应用签名
1. 生成密钥库文件
2. 配置签名信息
3. 构建签名版本

### Google Play 发布
1. 构建App Bundle
2. 上传到Google Play Console
3. 配置应用信息
4. 提交审核

## 🐛 常见问题

### 权限问题
**问题**: 无法选择PDF文件  
**解决**: 检查存储权限是否正确授予

### 渲染问题  
**问题**: PDF显示异常  
**解决**: 确保设备支持PDF渲染（API 21+）

### 性能问题
**问题**: 大文件加载慢  
**解决**: 
- 检查文件大小限制（100MB）
- 优化内存使用
- 考虑分页加载

## 📞 技术支持

如果遇到Android特定问题，请检查：
1. Android版本兼容性
2. 权限配置
3. 设备存储空间
4. 应用日志信息

---

*最后更新: 2025年9月*
