// Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/services.dart';

import 'package:pinnit_flutter/data/app_database.dart';
import 'package:pinnit_flutter/data/third_party_notification.dart';
import 'package:pinnit_flutter/services/notification_service.dart';

/// MethodChannel name — must match the Kotlin side
/// ([PinnitNotificationListenerService.CHANNEL_NAME]).
const _kChannel = 'pinnit/notification_listener';

/// Bridges the native [NotificationListenerService] and the Dart side.
///
/// * Native → Dart: the system fires `onNotificationPosted` for every
///   notification posted by another app. We persist it and emit it on
///   [captured] so the history screen can refresh live.
/// * Dart → Native: [openListenerSettings] / [isListenerEnabled] let the UI
///   drive the (system-owned) notification-access permission flow.
///
/// Implemented as a singleton so it stays alive for the whole app lifetime —
/// the cached [FlutterEngine] created in [PinnitApplication] keeps the Dart
/// isolate running even when no screen is visible, which is exactly what lets
/// us keep recording notifications in the background.
class NotificationListenerBridge {
  NotificationListenerBridge._() {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static final NotificationListenerBridge instance =
      NotificationListenerBridge._();

  final MethodChannel _channel = const MethodChannel(_kChannel);
  final StreamController<ThirdPartyNotification> _controller =
      StreamController<ThirdPartyNotification>.broadcast();

  /// Emits every captured third-party notification right after it is persisted.
  Stream<ThirdPartyNotification> get captured => _controller.stream;

  Future<void> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationPosted':
        final raw = call.arguments;
        if (raw is! Map) return;
        final map = Map<String, dynamic>.from(raw);

        final n = ThirdPartyNotification(
          packageName: (map['packageName'] as String?) ?? '',
          appName: map['appName'] as String?,
          title: map['title'] as String?,
          content: map['text'] as String?,
          postedAt: (map['postedAt'] as int?) ??
              DateTime.now().millisecondsSinceEpoch,
        );

        await AppDatabase.upsertThirdParty(n);
        _controller.add(n);

      case 'onOwnNotificationRemoved':
        // The user (or a launcher/OEM) swiped away one of our own pinned
        // notifications. Re-post every remaining pin so the panel stays
        // populated. If the pin was deleted inside the app, the DB row is
        // already soft-deleted, so it won't come back.
        final pinned = await AppDatabase.pinnedNotifications();
        await NotificationService.instance.repinAll(pinned);
    }
  }

  /// Open the system "Notification access" settings screen.
  /// The user must grant access there before history recording starts.
  ///
  /// Throws a [PlatformException] if the native side could not open settings;
  /// callers should surface manual instructions in that case.
  Future<void> openListenerSettings() async {
    await _channel.invokeMethod<void>('openListenerSettings');
  }

  /// Whether the user has granted notification-listener permission.
  Future<bool> isListenerEnabled() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isListenerEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Share a local text file via the system share sheet. Used by the history
  /// screen's "export" action so the user can send the exported `.txt` to any
  /// app (WeChat, cloud drive, Bluetooth…) without scoped-storage hassle.
  ///
  /// [path] must be a file under the app cache dir exposed by the native
  /// [FileProvider]; [title] is the chooser dialog title.
  Future<void> shareFile(String path, String title) async {
    try {
      await _channel.invokeMethod<void>('shareFile', {
        'path': path,
        'title': title,
      });
    } on PlatformException {
      rethrow;
    }
  }

  /// Save a local text file into the system Downloads folder (via native
  /// MediaStore) so the user can open it from any file manager without going
  /// through a third-party sharing app. Returns true on success.
  Future<bool> saveFileToDownloads(String path, String displayName) async {
    try {
      final ok = await _channel.invokeMethod<bool>('saveFileToDownloads', {
        'path': path,
        'name': displayName,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }
}
