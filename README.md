# Pinnit (Flutter)

A **Flutter** reimplementation of [Pinnit](https://play.google.com/store/apps/details?id=dev.sasikanth.pinnit2)
— the Android app that lets you **pin notes & notifications to your notification
panel** so important info never gets lost.

> The original ([`msasikanth/pinnit`](https://github.com/msasikanth/pinnit),
> Apache-2.0, Kotlin) is open source and archived. This project faithfully ports
> its data model and behaviours to Flutter, so it runs on the same Android
> surface with a Material 3 UI.

---

## Features

### Implemented
- **Create & pin notifications** to the notification shade (persistent / `ongoing`).
- **Edit / unpin / delete** with soft-delete (mirrors the original `deletedAt`).
- **Search & filter** the list by title or content.
- **Schedule** one-shot or **Daily / Weekly / Monthly** repeating reminders
  (system alarms, work even when the app is closed).
- **Material 3** light / dark themes with a quick toggle.
- **Notification history** 🆕 — a `NotificationListenerService` records other
  apps' notifications into a searchable log; tap any item to add a personal
  note. Grant *Settings → Notification access* for Pinnit to start recording
  (the app shows a one-tap "Enable" banner until you do).

---

## Project layout

```
lib/
  main.dart                      # entry: init bridges + NotificationService
  app.dart                       # MaterialApp + theme + navigator key
  providers.dart                 # themeMode + thirdParty export
  data/
    notification_model.dart      # PinnitNotification + Schedule (== Room entity)
    third_party_notification.dart# ThirdPartyNotification (history capture)
    app_database.dart            # sqflite wrapper (v2: + ThirdPartyNotification)
  repositories/
    notifications_repository.dart# Riverpod Notifier: pinned list + mutations
    third_party_repository.dart # Riverpod Notifier: history list + mutations
  services/
    notification_service.dart    # flutter_local_notifications: pin/schedule
    notification_listener_bridge.dart # MethodChannel singleton <-> native
  notifications/
    notifications_screen.dart    # home list + search + history entry
    notification_tile.dart        # list row + pin toggle
    history_screen.dart          # captured-notifications log + notes
  editor/
    editor_screen.dart           # create/edit + schedule UI
  theme/theme.dart               # M3 light/dark
  utils/navigator_key.dart        # deep-link from notification tap
android/
  app/src/main/kotlin/com/pinnit/flutter/
    PinnitApplication.kt         # cached FlutterEngine (background listener)
    PinnitNotificationListenerService.kt # captures other apps' notifications
    MainActivity.kt              # uses the cached engine
  app/src/main/AndroidManifest.xml # permissions + listener-service registration
docs/
  NOTIFICATION_LISTENER.md       # listener design notes
```

### How it maps to the original

| Original (Kotlin)            | Flutter port                         |
|------------------------------|--------------------------------------|
| `PinnitNotification` (Room)  | `data/notification_model.dart`       |
| `Schedule` / `ScheduleType`  | same, in the model file              |
| Room DAO queries             | `data/app_database.dart` (sqflite)   |
| Mobius state machine         | Riverpod `Notifier`                  |
| `NotificationListener`/scheduler | `services/notification_service.dart` |
| Material 3 UI               | `theme/` + `notifications/` + `editor/` |

---

## Getting started

### Prerequisites
- [Flutter 3.19+](https://docs.flutter.dev/get-started/install) (stable)
- Android SDK (API 34 recommended) + an emulator or device
- `flutter doctor` should report no Android issues

### Run it

> This repo already ships the **complete Android shell** (Gradle wrapper,
> manifest, launcher icon). You do **not** need to run `flutter create .` —
> doing so would overwrite the custom `AndroidManifest.xml` and break the
> notification-listener registration.

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run on a connected device / emulator
flutter run
```

### Build a release APK

On a machine with Android Studio (or the cmdline-tools + a JDK):

```bash
flutter pub get
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

Transfer `app-release.apk` to your phone, tap it, and allow install from
this source. On first launch, open **History** (top bar) and tap **Enable** to
grant *Notification access* — that's what lets Pinnit record other apps'
notifications.

### Notes
- For a production launcher icon, run `flutter_launcher_icons` instead of the
  placeholder vector supplied here.
- Scheduling uses exact alarms; on Android 12+ the `SCHEDULE_EXACT_ALARM`
  permission (already declared) is required.
- The notification-listener feature requires the user to grant *Notification
  access* in system settings (no way around it — Android security model).

---

## License

The original Pinnit is © 2020 Sasikanth Miriyampalli, Apache-2.0
(https://github.com/msasikanth/pinnit).

This Flutter port is provided under the same Apache-2.0 license for the
portions derived from it. The full license text is in [`LICENSE`](LICENSE),
and attribution / modification notices are in [`NOTICE`](NOTICE). Core source
files carry a "modified, derived from Pinnit" header at the top.
