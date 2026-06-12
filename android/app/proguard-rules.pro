# Flutter specific ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class com.tod.app.** { *; }

# Play Core (needed for Flutter's deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
