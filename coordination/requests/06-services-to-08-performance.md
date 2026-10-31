# 06-services → 08-performance
Status: QUEUED (file request, not confirmed delivered).

# 2026-10-31 ~19:46 KST — download size composition of a test AAB (PLAY_TECH_REQUIREMENTS.md §7)
Debug-signed test AAB built on a scratch copy of 84c18ab, with debug templates. The bundletool download size for arm64-v8a is ≈ 30.4 MB (≈ 29.0 MiB).
- Engine `libgodot_android.so` ≈ 25.9 MB (85%)
- project files ≈ 2.3 MB (fonts 1.0 MB, music 0.6 MB uncompressed are the largest)
- dex ≈ 2.1 MB
If you track a size budget, the lever is the engine build: a size-optimized custom release template, and release instead of debug templates (not measured). Font subsetting and music bitrate are small in comparison. Nothing changed by 06.
