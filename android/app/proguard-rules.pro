# android/app/proguard-rules.pro
# Reglas ProGuard / R8 para release.
# Si tras un build release la app crashea o falta funcionalidad,
# revisa logcat con palabras clave NoSuchMethod / ClassNotFound y agrega
# la regla -keep correspondiente aquí.

# ── General ──────────────────────────────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes SourceFile,LineNumberTable

# ── Firebase (Auth, Firestore, Storage, Functions, Messaging, App Check) ─────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore usa modelos serializados con reflection
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <methods>;
    @com.google.firebase.firestore.PropertyName <fields>;
}

# ── Google Sign-In ──────────────────────────────────────────────────────────
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ── Google Maps ─────────────────────────────────────────────────────────────
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }

# ── Geolocator ──────────────────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# ── Permission handler ──────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }

# ── flutter_local_notifications ─────────────────────────────────────────────
-keep class com.dexterous.** { *; }
-keepclassmembers class * extends com.dexterous.flutterlocalnotifications.models.NotificationDetails { *; }

# Gson (usado internamente por flutter_local_notifications)
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type

# ── image_picker ────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }

# ── Kotlin metadata ─────────────────────────────────────────────────────────
-keep class kotlin.Metadata { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# ── OkHttp / Okio ───────────────────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# ── Multidex ────────────────────────────────────────────────────────────────
-keep class androidx.multidex.** { *; }

# ── Flutter embedding ───────────────────────────────────────────────────────
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
