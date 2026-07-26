// Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:pinnit_flutter/data/notification_model.dart';
import 'package:pinnit_flutter/editor/editor_screen.dart';
import 'package:pinnit_flutter/services/pins_bridge.dart';
import 'package:pinnit_flutter/utils/navigator_key.dart';

/// Wraps [FlutterLocalNotificationsPlugin] for *scheduled* notifications, and
/// delegates *pinned* (ongoing) notifications to the native layer via
/// [PinsBridge] so their action buttons ("复制" / "取消固定") work reliably
/// from the notification shade (see [PinnitPins] / [PinnitActionReceiver]).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _scheduleChannelId = 'pinnit_scheduled';
  static const _scheduleChannelName = 'Scheduled';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _scheduleChannelId,
      _scheduleChannelName,
      description: '定时提醒通知',
      importance: Importance.max,
    ));
  }

  /// Returns `true` if the user (already) granted permission, `false` if
  /// denied, and `null` on unsupported platforms.
  Future<bool?> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return android?.requestNotificationsPermission();
  }

  /// Stable, positive 32-bit int id derived from the notification uuid.
  ///
  /// Android notification ids must fit in a signed 32-bit integer
  /// ([-2^31, 2^31-1]). We take the first 8 hex chars of the UUID and mask
  /// them into that range, avoiding both collisions from [String.hashCode]
  /// and the overflow that made some notifications fail to post.
  ///
  /// MUST match [PinnitPins.idOf] on the native side.
  int _id(String uuid) {
    final hex = uuid.replaceAll('-', '').substring(0, min(8, uuid.length));
    final parsed = int.tryParse(hex, radix: 16) ?? uuid.hashCode;
    return parsed & 0x7FFFFFFF;
  }

  /// Public version of [_id] so the listener bridge can correlate removed
  /// system notifications back to our own pinned notifications.
  int idOf(String uuid) => _id(uuid);

  void _onNotificationTapped(NotificationResponse response) {
    final uuid = response.payload;
    if (uuid == null) return;
    // Body tap of a scheduled notification opens its editor. Pinned
    // notifications are handled natively (see [PinsBridge] / [MainActivity]).
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => EditorScreen(uuid: uuid)),
    );
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

  /// Schedule a one-shot or recurring notification.
  ///
  /// Daily / Weekly / Monthly repeats use [DateTimeComponents] so the system
  /// alarm reschedules itself automatically (works even when the app is
  /// closed).
  Future<void> schedule(PinnitNotification n) async {
    final dt = n.schedule?.scheduledDateTime;
    if (dt == null) return;

    final scheduled = tz.TZDateTime.from(dt, tz.local);
    const androidDetails = AndroidNotificationDetails(
      _scheduleChannelId,
      _scheduleChannelName,
      channelDescription: '定时提醒通知',
      importance: Importance.max,
      priority: Priority.max,
    );

    DateTimeComponents? components;
    switch (n.schedule!.type) {
      case ScheduleType.daily:
        components = DateTimeComponents.time;
      case ScheduleType.weekly:
        components = DateTimeComponents.dayOfWeekAndTime;
      case ScheduleType.monthly:
        components = DateTimeComponents.dayOfMonthAndTime;
      case null:
        components = null;
    }

    await _plugin.zonedSchedule(
      _id(n.uuid),
      n.title,
      n.content,
      scheduled,
      const NotificationDetails(android: androidDetails),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: components,
    );
  }

  Future<void> cancelSchedule(String uuid) async {
    await cancelPinned(uuid);
  }
}
