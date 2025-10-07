# Flutter 相关
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }

# PDF 相关 - flutter_pdfview
-keep class com.github.barteksc.pdfviewer.** { *; }
-dontwarn com.github.barteksc.pdfviewer.**

# PDF 渲染相关
-keep class com.shockwave.pdfium.** { *; }
-dontwarn com.shockwave.pdfium.**

# file_picker 相关
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-dontwarn com.mr.flutter.plugin.filepicker.**

# path_provider 相关  
-keep class io.flutter.plugins.pathprovider.** { *; }
-dontwarn io.flutter.plugins.pathprovider.**

# shared_preferences 相关
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**

# 保持注解
-keepattributes *Annotation*

# 保持异常信息
-keepattributes SourceFile,LineNumberTable

# 保持泛型信息
-keepattributes Signature

# 保持内部类
-keepattributes InnerClasses,EnclosingMethod
