# Phase 2 — Listening to other apps' notifications (history)

Pinnit's headline feature is a **searchable history of notifications from every
app**. On Android this requires a `NotificationListenerService`, which the user
enables in system settings (Settings → Notifications → Notification access).

This Flutter port does **not** ship the listener in the MVP to keep the core
build dependency-free and verifiable. When you're ready, enable it as follows.

## 1. Add the dependency

`pubspec.yaml`:

```yaml
dependencies:
  notification_listener_service: ^0.2.0
```

```bash
flutter pub get
```

## 2. Declare the listener service in the manifest

`android/app/src/main/AndroidManifest.xml` (inside `<application>`):

```xml
<service
    android:name="com.alhiane.notification_listener_service.NotificationListenerService"
    android:label="@string/app_name"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
    <intent-filter>
        <action android:name="android.service.notification.NotificationListenerService" />
    </intent-filter>
</service>
```

## 3. Dart side — `lib/services/listener_service.dart`

```dart
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:pinnit_flutter/data/app_database.dart';
import 'package:pinnit_flutter/data/notification_model.dart';

class ListenerService {
  static final ListenerService instance = ListenerService._();
  ListenerService._();

  Future<bool> isGranted() =>
      NotificationListenerService.isPermissionGranted();

  Future<void> requestPermission() =>
      NotificationListenerService.requestPermission();

  void start() {
    NotificationListenerService.notificationsStream.listen((event) {
      // event.packageName, event.title, event.text, event.postTime ...
      final n = PinnitNotification(
        title: event.title ?? event.packageName ?? 'Unknown',
        content: event.text,
        isPinned: false, // history entries are not pinned by default
      );
      AppDatabase.save(n);
    });
  }
}
```

Call `ListenerService.instance.start()` after permission is granted (e.g. from a
settings screen), and surface `isGranted()` so the UI can prompt the user to
enable notification access.

## Notes

- Listened notifications are stored with `isPinned = false`, so they appear in
  the existing list as history but do not occupy the shade.
- Respect privacy: this data stays on-device, exactly like the original Pinnit.
- The `notification_listener_service` package version above is indicative —
  check [pub.dev](https://pub.dev/packages/notification_listener_service) for
  the current API before wiring it in.
