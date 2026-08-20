# Flutter + Firebase keep rules. R8 full mode strips these otherwise.
-keep class io.flutter.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# flutter_local_notifications reflects on its receivers.
-keep class com.dexterous.** { *; }

# Camera plugin uses reflection for the platform channel bridge.
-keep class io.flutter.plugins.camerax.** { *; }
-keep class androidx.camera.** { *; }

-dontwarn javax.annotation.**
-dontwarn org.jetbrains.annotations.**
