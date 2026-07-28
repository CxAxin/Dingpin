#!/usr/bin/env bash
set -u
export JAVA_HOME='C:\Users\27218\AppData\Local\Temp\apk_build\jdk17'
export ANDROID_HOME='C:\Users\27218\AppData\Local\Temp\apk_build\android-sdk'
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export FLUTTER_SDK="/c/Users/27218/AppData/Local/Temp/flutter-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$FLUTTER_SDK/bin:$PATH"

PROJ="/c/Users/27218/WorkBuddy/2026-07-25-20-57-33/pinnit_flutter"
APK="$PROJ/android/app/build/outputs/apk/release/app-release.apk"
LOG="$PROJ/build_release2.log"

cd "$PROJ" || { echo "cd failed"; exit 2; }

echo "BUILD_START $(date)" | tee "$LOG"

# Remove any stale APK so we never mistake an old artifact for a new one.
rm -f "$APK"
echo "removed stale apk" | tee -a "$LOG"

"$FLUTTER_SDK/bin/flutter" build apk --release --target-platform android-arm64 --android-skip-build-dependency-validation >> "$LOG" 2>&1
RC=$?
echo "FLUTTER_BUILD_RC=$RC" | tee -a "$LOG"

# NOTE: do NOT trust flutter's exit code alone. On this host flutter
# frequently exits 1 with "Gradle build failed to produce an .apk file"
# even though Gradle DID produce the APK at the expected path (path
# detection quirk). The artifact check below is the real gate.
if [ ! -f "$APK" ]; then
  echo "BUILD FAILED: apk not found at $APK (flutter rc=$RC)" | tee -a "$LOG"
  exit 1
fi
if [ "$RC" -ne 0 ]; then
  echo "flutter rc=$RC but apk exists -> treating as false failure, verifying artifact" | tee -a "$LOG"
fi

# Verify the APK is a valid zip (not a truncated/corrupt artifact).
if ! unzip -t "$APK" >/dev/null 2>&1; then
  echo "BUILD FAILED: apk is not a valid zip" | tee -a "$LOG"
  exit 1
fi

SIZE=$(stat -c%s "$APK" 2>/dev/null || echo 0)
echo "BUILD OK: $APK size=$SIZE bytes" | tee -a "$LOG"
echo "BUILD_DONE $(date)" | tee -a "$LOG"
exit 0
