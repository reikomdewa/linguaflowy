# -- Flutter Wrapper --
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# -- LiveKit & WebRTC (CRITICAL) --
-keep class org.webrtc.** { *; }
-keep class livekit.org.webrtc.** { *; }
-keep class io.livekit.** { *; }
-keep class com.twilio.** { *; }
-keepattributes *Annotation*

# -- HTTP & OkHttp (Used for networking) --
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.squareup.okhttp.** { *; }
-keep interface com.squareup.okhttp.** { *; }
-dontwarn com.squareup.okhttp.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# -- Google Play Core (Fix for Missing Class Errors) --
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.**

#livekit
-keep class io.flutter.plugin.** { *; }
-keep class com.cloudwebrtc.** { *; }
-keep class livekit.** { *; }
-keep class org.webrtc.** { *; }