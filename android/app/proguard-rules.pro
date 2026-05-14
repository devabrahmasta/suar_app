-keep class io.flutter.plugins.** { *; }
-keep class com.example.suar_app.** { *; }
-keep class kotlin.** { *; }
-keep class latlong2.** { *; }

# Workaround for Dio in Release Mode
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Workaround for LatLng classes
-keep class * implements java.io.Serializable { *; }
