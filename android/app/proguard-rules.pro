# قواعد أساسية للحفاظ على الأكواد المطلوبة
-dontwarn androidx.window.**
-keep class androidx.window.** { *; }

# حماية Flutter والمكتبات المرتبطة
-keep class io.flutter.** { *; }
-keep class androidx.** { *; }
-dontwarn io.flutter.**

# حماية مكتبة HTTP
-keep class java.net.** { *; }
-keep class org.apache.http.** { *; }
-dontwarn org.apache.http.**

# حماية ملفات JSON والتسلسل
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# حماية الأذونات والملفات
-keep class * extends android.app.Activity
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver
-keep class * extends android.content.ContentProvider

# حماية فئات التطبيق المخصصة
-keep class sy.alhalmarket.syrian_arab.** { *; }