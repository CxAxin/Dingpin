// Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:pinnit_flutter/data/notification_model.dart';
import 'package:pinnit_flutter/services/pins_bridge.dart';

/// Wraps [FlutterLocalNotificationsPlugin] for notification *permission*
/// checks, and delegates *pinned* (ongoing) notifications to the native layer
/// via [PinsBridge] so their action buttons ("复制" / "取消固定") work reliably
/// from the notification shade (see [PinnitPins] / [PinnitActionReceiver]).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
  }

  /// Returns `true` if the user (already) granted permission, `false` if
  /// denied, and `null` on unsupported platforms.
  Future<bool?> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return android?.requestNotificationsPermission();
  }

  /// Post a persistent (ongoing) notification that behaves like the original
  /// Pinnit pin. Delegated to the native layer so the action buttons work from
  /// the shade regardless of Flutter's background state.
  Future<void> showPinned(PinnitNotification n) async {
    await PinsBridge.instance.showPinned(n);
  }

  Future<void> cancelPinned(String uuid) async {
    await PinsBridge.instance.cancelPinned(uuid);
  }

  /// Re-post every pinned notification to the shade.
  ///
  /// Called when the user (or an aggressive OEM) swipes away one of our
  /// ongoing notifications. Because each pin has a stable id, calling show()
  /// again simply re-creates it without duplicates.
  Future<void> repinAll(List<PinnitNotification> notifications) async {
    for (final n in notifications.where((n) => n.isPinned)) {
      try {
        await showPinned(n);
      } catch (e, st) {
        debugPrint('repinAll failed for ${n.uuid}: $e\n$st');
      }
    }
  }
}
