#!/usr/bin/env bash
# Fallback builder for Dingpin 2.9.3 (arm64 release).
#
# Why this exists: on this host `flutter build apk` dies immediately with
#   ProcessException: 所有的管道范例都在使用中。 (process_win.cc:742)
# i.e. the Dart VM's Process.start cannot create the stdio pipes needed to
# launch gradlew.bat. Gradle itself is healthy (gradlew.bat --version works),
# so we skip the dart launcher entirely and drive Gradle directly with the
# exact argument list flutter would have used.
set -u

export PATH="/usr/bin:/bin:/mingw64/bin:/c/Windows/System32:/c/Windows:/c/Windows/System32/WindowsPowerShell/v1.0${PATH:+:$PATH}"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy
export NO_PROXY="*"
export no_proxy="*"

export JAVA_HOME='C:\android-build\jdk\extracted\jdk-17.0.10+7'
export ANDROID_HOME='C:\android-build\sdk-dingpin'
export ANDROID_SDK_ROOT="$ANDROID_HOME"

PROJ="/c/Users/27218/WorkBuddy/2026-07-25-20-57-33/pinnit_flutter"
APK="$PROJ/android/app/build/outputs/flutter-apk/app-release.apk"
LOG="$PROJ/build_293_gradle.log"

cd "$PROJ/android" || { echo "cd failed"; exit 2; }

echo "GRADLE_START $(date)" | tee "$LOG"
rm -f "$APK"

./gradlew.bat -q \
  -PskipDependencyChecks=true \
  -Ptarget-platform=android-arm64 \
  -Ptarget='lib\main.dart' \
  -Pbase-application-name=android.app.Application \
  -Pdart-defines=RkxVVFRFUl9WRVJTSU9OPTMuNDQuOA==,RkxVVFRFUl9DSEFOTkVMPXN0YWJsZQ==,RkxVVFRFUl9HSVRfVVJMPWh0dHBzOi8vZ2l0aHViLmNvbS9mbHV0dGVyL2ZsdXR0ZXIuZ2l0,RkxVVFRFUl9GUkFNRVdPUktfUkVWSVNJT049MDU4ZTBhZjJjMg==,RkxVVFRFUl9FTkdJTkVfUkVWSVNJT049MGNkNjEwNzE3Yg==,RkxVVFRFUl9EQVJUX1ZFUlNJT049My4xMi4y \
  -Pdart-obfuscation=false \
  -Ptrack-widget-creation=true \
  -Ptree-shake-icons=true \
  assembleRelease >> "$LOG" 2>&1
RC=$?
echo "GRADLE_RC=$RC" | tee -a "$LOG"

if [ ! -f "$APK" ]; then
  echo "FAILED: no apk at $APK" | tee -a "$LOG"
  exit 1
fi
if ! unzip -t "$APK" >/dev/null 2>&1; then
  echo "FAILED: apk not a valid zip" | tee -a "$LOG"
  exit 1
fi

OUT="/c/Users/27218/WorkBuddy/2026-07-25-20-57-33/Dingpin-2.9.3-arm64.apk"
cp -f "$APK" "$OUT"
echo "BUILD_OK: $OUT size=$(stat -c%s "$OUT") bytes" | tee -a "$LOG"
echo "BUILD_DONE $(date)" | tee -a "$LOG"
exit 0
