#!/usr/bin/env bash
# Build Dingpin 2.9.0 release APK (arm64-only, bare versionCode) with the
# C:\android-build toolchain.
#
# NOTE: do NOT set MSYS_NO_PATHCONV=1 here. It stops Git Bash from converting
# PATH when it spawns flutter.bat's cmd children, and cmd then cannot find
# `where`/`git` ("'WHERE' is not recognized…", "Unable to find git in your
# PATH"). We rebuild a known-good PATH below (System32, PowerShell dir,
# /mingw64/bin, …) because the background shim can launch with an empty PATH.
set -u

# Bash on this host can start with an empty PATH, which breaks coreutils
# (unzip/stat/cp) used at the end of this script. Restore the basics first.
# Flutter also needs PowerShell on Windows; when invoked via the background
# shim the inherited PATH is empty, so add the PowerShell dir explicitly
# (otherwise pub get / build apk dies with "PowerShell executable not found").
export PATH="/usr/bin:/bin:/mingw64/bin:/c/Windows/System32:/c/Windows:/c/Windows/System32/WindowsPowerShell/v1.0${PATH:+:$PATH}"

# The host injects HTTP(S)_PROXY — a LOCAL egress proxy that is flaky (it drops
# connections mid-build, which makes Gradle's dependency downloads hang or come
# back empty and the build dies with
#   "Cannot query the value of this provider because it has no value available").
# Verified: dl.google.com and storage.googleapis.com (Google Maven + the Flutter
# engine repo) are reachable DIRECTLY, with no proxy. So DROP the proxy for the
# build so no tool routes through it, and strip any stale systemProp proxy from
# gradle.properties. Gradle does not read env proxy vars; the only Google-Maven
# fix needed is the init.gradle remap (aliyun-google -> dl.google.com), because
# aliyun's google mirror serves empty 200s for com.android.tools artifacts.
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy
export NO_PROXY="*"
export no_proxy="*"
GP="$HOME/.gradle/gradle.properties"
if [ -f "$GP" ]; then
  grep -vE '^systemProp\.(http|https)\.proxy(Host|Port)=' "$GP" > "${GP}.tmp" && mv -f "${GP}.tmp" "$GP"
fi
echo "PROXY_VIA=none (direct; proxy dropped)"

export JAVA_HOME='C:\android-build\jdk\extracted\jdk-17.0.10+7'
# The Temp SDK is the only one with a full NDK (28.2.x) + cmake installed.
# android-build\sdk has NO ndk dir -> Flutter's NDK provider comes back empty
# ("Cannot query the value of this provider because it has no value available"
# while resolving :app:compileReleaseJavaWithJavac). This is the real root cause.
export ANDROID_HOME='C:\Users\27218\AppData\Local\Temp\apk_build\android-sdk'
export ANDROID_SDK_ROOT="$ANDROID_HOME"

FLUTTER_SDK="/c/android-build/flutter_full/flutter"
export PATH="/c/android-build/jdk/extracted/jdk-17.0.10+7/bin:$FLUTTER_SDK/bin:$ANDROID_HOME/platform-tools:$PATH"

PROJ="/c/Users/27218/WorkBuddy/2026-07-25-20-57-33/pinnit_flutter"
APK="$PROJ/android/app/build/outputs/flutter-apk/app-release.apk"
LOG="$PROJ/build_290.log"

cd "$PROJ" || { echo "cd failed"; exit 2; }

echo "BUILD_START $(date)" | tee "$LOG"
echo "JAVA_HOME=$JAVA_HOME" | tee -a "$LOG"
rm -f "$APK"

# Resolve deps once with a real pub get, then build with --no-pub (matches the
# known-good 2.8.8 invocation that produced a working APK). pubspec.yaml now
# carries a dependency_overrides entry pointing sqflite_android at a locally
# patched copy (JDK 17-safe Locale/Thread APIs); the earlier provider-error
# root cause was a corrupted Gradle modules-2 cache + missing core-for-system-modules.jar.
"$FLUTTER_SDK/bin/flutter" pub get >> "$LOG" 2>&1
echo "PUBGET_RC=$?" | tee -a "$LOG"

"$FLUTTER_SDK/bin/flutter" build apk --release --target-platform android-arm64 --no-pub --android-skip-build-dependency-validation >> "$LOG" 2>&1
RC=$?
echo "FLUTTER_RC=$RC" | tee -a "$LOG"

# flutter's exit code is NOT trustworthy on this host: it often reports
# "Gradle build failed to produce an .apk file" (exit 1) while the APK really
# exists under android/app/build/outputs/. Judge success by the artifact.
if [ ! -f "$APK" ]; then
  echo "BUILD_FAILED: no apk at $APK" | tee -a "$LOG"
  exit 1
fi
if ! unzip -t "$APK" >/dev/null 2>&1; then
  echo "BUILD_FAILED: apk is not a valid zip" | tee -a "$LOG"
  exit 1
fi

OUT="/c/Users/27218/WorkBuddy/2026-07-25-20-57-33/Dingpin-2.9.0-arm64.apk"
cp -f "$APK" "$OUT"
SIZE=$(stat -c%s "$OUT" 2>/dev/null || echo 0)
echo "BUILD_OK: $OUT size=$SIZE bytes" | tee -a "$LOG"
echo "BUILD_DONE $(date)" | tee -a "$LOG"
exit 0
