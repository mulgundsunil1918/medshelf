# ── Flutter core ───────────────────────────────────────────────────────────────
# Flutter uses reflection and JNI — never touch the embedding layer.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ── Plugin registrant ──────────────────────────────────────────────────────────
-keep class com.medshelf.medshelf.GeneratedPluginRegistrant { *; }

# ── AndroidX / Jetpack ─────────────────────────────────────────────────────────
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.**

# ── SQLite / sqflite ───────────────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }

# ── receive_sharing_intent ─────────────────────────────────────────────────────
-keep class com.kasem.sharing.** { *; }

# ── permission_handler ─────────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }

# ── file_picker ────────────────────────────────────────────────────────────────
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# ── open_filex ─────────────────────────────────────────────────────────────────
-keep class com.crazecoder.openfile.** { *; }

# ── video_player ───────────────────────────────────────────────────────────────
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# ── Google Fonts (loads fonts by name at runtime) ──────────────────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ── Kotlin coroutines / serialization ─────────────────────────────────────────
-keepattributes *Annotation*, Signature, Exception
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-dontwarn kotlinx.coroutines.**

# ── General Java ──────────────────────────────────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
