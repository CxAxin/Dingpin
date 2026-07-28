# Build plan — Pinnit Flutter port

**Goal:** a runnable Flutter clone of the open-source Android app
[Pinnit](https://play.google.com/store/apps/details?id=dev.sasikanth.pinnit2),
pinning notes/reminders to the notification shade.

Reference source (read-only):
`https://github.com/msasikanth/pinnit` (Apache-2.0, Kotlin, archived 2024-06-27).

## Status

| Phase | Scope | Status |
|-------|-------|--------|
| 0 | Locate source + confirm approach | ✅ |
| 1 | Project scaffold, deps, data model (sqflite) | ✅ |
| 2 | Notification service: pin (ongoing) + schedule (daily/weekly/monthly) | ✅ |
| 3 | UI: home list + search, editor, M3 themes | ✅ |
| 4 | Android native: manifest permissions, icon, Gradle | ✅ |
| 5 | `flutter pub get` + `dart analyze` (clean ✅) | ✅ |
| 6 | Notification history via `NotificationListenerService` | ✅ |
| 7 | Build release APK (background, on local sandbox) | ⏳ running |

## Phase 6 — notification history (DONE)
Mirrors the original Pinnit "notification history" feature: records other
apps' notifications locally, searchable/filterable, with a user note per item.

- **Native side** (`android/.../kotlin/com/pinnit/flutter/`)
  - `PinnitApplication.kt` — pre-warms a cached `FlutterEngine` so the
    listener can stream to Dart even with no UI on screen.
  - `PinnitNotificationListenerService.kt` — `NotificationListenerService`
    that forwards `packageName/appName/title/text/postedAt` over a
    `MethodChannel`, exposes `openListenerSettings`/`isListenerEnabled`, and
    ignores our own pinned/scheduled notifications.
- **Dart side**
  - `lib/services/notification_listener_bridge.dart` — `MethodChannel`
    (`pinnit/notification_listener`) singleton; persists every captured
    notification and exposes a `captured` stream.
  - `lib/repositories/third_party_repository.dart` — `NotifierProvider`
    mirroring `NotificationsNotifier`; keeps the list live via the stream.
  - `lib/data/third_party_notification.dart` + `AppDatabase`
    (`ThirdPartyNotification` table v2, de-dupe window, `note` column).
  - `lib/notifications/history_screen.dart` — search, listener-off banner
    with "Enable" deep-link to system settings, per-item note editor,
    swipe-to-delete, clear-all.
- **Permission**: user must grant *Settings → Notification access* for Pinnit
  (the app shows a banner with a one-tap "Enable" until they do).
- See `docs/NOTIFICATION_LISTENER.md` for the full design notes.

## Still open (next)
- [ ] Re-post pinned notifications after reboot (BOOT_COMPLETED receiver).
- [ ] Persist theme + last-filter with `shared_preferences`/`DataStore`.
- [ ] Onboarding permission flow (POST_NOTIFICATIONS, exact alarm, listener).
- [ ] Tests (widget + repository).

## Design decisions
- **sqflite over drift** — no `build_runner` step, maximally "just works".
- **Riverpod Notifier** replaces the original's Mobius state machine.
- **flutter_local_notifications** handles both the pinned `ongoing`
  notification and `zonedSchedule` with `DateTimeComponents` for repeats.
- Package id `com.pinnit.flutter` (distinct from the original
  `dev.sasikanth.pinnit2`).
