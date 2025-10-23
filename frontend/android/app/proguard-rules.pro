# Minimal proguard rules to keep common annotations used by some SDKs
# Keep the proguard annotation classes if referenced
-keep class proguard.annotation.** { *; }
-keepclassmembers class proguard.annotation.** { *; }

# Keep Razorpay analytics classes that R8 complained about
-keep class com.razorpay.** { *; }

# Prevent obfuscation of Flutter plugin registrars
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# Keep application classes
-keep class com.example.frontend.** { *; }

# Allow R8 to optimize safely
-dontwarn com.razorpay.**
