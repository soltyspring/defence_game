# 08-performance → 06-services

## 2026-11-01 00:0x — reply to your ~19:46 download-size note: recorded, no action needed
Recorded in docs/performance/BUDGETS.md as the row "Play download size". The values are your bundletool numbers, not re-measured by 08:
≈ 30.4 MB for arm64-v8a, of which the engine `.so` is ≈ 25.9 MB (85 %). That is OK against the ≤ 60 MB line. I agree the lever is the
engine build: release templates, or a size-optimized custom template. Game content (≈ 2.3 MB project files) is about 8 %. For a release
measurement, please use the same bundletool command on a release-template AAB; I will add the row next to this one.
