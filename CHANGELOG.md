# Changelog

All notable changes to **Dingpin（顶顶）** are documented here.

> **Version-control note:** releases **2.6.8 – 2.8.8** were shipped straight
> from the working tree **without Git tags**, so this file starts at **2.9.0** —
> the first release tagged in Git. The entry below describes what 2.9.0
> contains relative to the last tagged release (`v2.6.7`), and marks what is
> genuinely *new since 2.8.8*.

## [2.9.0] - 2026-09-23

### ✨ Animation Phase 2（动效二期）— new in 2.9.0
- **Centralized motion system** (`lib/theme/motion.dart`): one source of truth
  for every easing curve and duration. UI animations stay **< 300ms**; exits
  are ~20% faster than entrances; scale never reaches 0 (no cheap "pop out").
- **New widget library** (`lib/widgets/`):
  - `AppDialog` — unified dialog: 24px radius, warm-glass card, top icon,
    full-width rounded buttons. Replaces bare `AlertDialog`.
  - `AppMenu` — pop-up menu that **scales from its trigger point** (150ms
    fade-in), replacing ad-hoc `showMenu` usages.
  - `AppPageRoute` — unified page transition (240ms in / 180ms out).
  - `PressScale` — press feedback (130ms, scale to 0.97).
  - `UndoToast` — undo banner.
  - `WarmField` — warm-tinted filled text field.
  - `AppAnimatedList` — animated list insert/remove.
  - `AuroraBackdrop` — warm-gold paper-like background (present since 2.8.8;
    now adopted app-wide via the new backdrop widget).
- **Shader warm-up** (`lib/utils/shader_warmup.dart`): pre-warms shaders at
  startup to cut first-frame jank.
- **History screen rework**: rebuilt on the new motion system + widget library
  (list / tile / menu feel unified).

### 🔧 Dependencies & build
- Add `liquid_glass_easy` (Apple-style glassmorphism effect).
- `dependency_overrides` (build-environment patches, **do not remove**):
  - `sqflite_android` → local patched copy (`packages/sqflite_android`) so it
    compiles under the JDK 17 toolchain (uses JDK-17-safe `Locale` / `getId`
    instead of Java 19 APIs).
  - `path_provider_android` pinned to `2.2.20` to **bypass the broken local
    NDK sysroot** (empty `sysroot/usr/lib` → `unable to find library -lc`).
    2.2.20 is the last MethodChannel-only release (no `jni` native build), and
    still satisfies `path_provider 2.1.6`'s `^2.2.5` constraint.

### ✅ Already shipped in 2.8.8 (carried into 2.9.0)
- **Notification blocklist** (`lib/services/blocklist_service.dart` +
  `lib/settings/blocklist_screen.dart`): silently drop captured notifications
  whose title / body / app name contains a keyword (e.g. "正在扫描").
- **Quick Settings tile "New note"** (`NewNoteTileService.kt`): pull down the
  shade and tap to jump straight into a blank editor (pre-warmed engine, no
  main-UI warm-up).
- **Glass card** (`lib/widgets/glass_card.dart`) and early aurora background.

### 🧱 Build
- `versionCode` 290, `versionName` 2.9.0, `compileSdk` 36.
- Deliverable: `Dingpin-2.9.0-arm64.apk` (arm64 runnable code; plugin
  prebuilts for other ABIs are also bundled — harmless on arm64 devices).

---

## [2.6.7] - (last Git-tagged release; earlier history)
Baseline rebrand of Pinnit → Dingpin, with pin-from-history, zh/en i18n,
Material 3 three-tab navigation, notification-history export, and About screen.
