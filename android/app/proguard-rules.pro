# FFmpegKit
-keep class com.arthenica.ffmpegkit.** { *; }

# ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.firebase.** { *; }

# MediaStore (사용 시)
-keep class io.github.kaisou1101.mediastore.** { *; }

# JSON (gson 쓸 경우)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }