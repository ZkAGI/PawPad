# Disable obfuscation and optimization for easier debugging
-dontobfuscate
-dontoptimize
-ignorewarnings

# Keep all classes - very permissive approach
-keep class ** { *; }

# Ignore all warnings to prevent build failures
-dontwarn **