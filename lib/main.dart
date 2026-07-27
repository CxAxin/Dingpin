import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinnit_flutter/app.dart';
import 'package:pinnit_flutter/providers.dart';
import 'package:pinnit_flutter/services/notification_listener_bridge.dart';
import 'package:pinnit_flutter/services/notification_service.dart';
import 'package:pinnit_flutter/services/pins_bridge.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-warm the listener bridge so it can record notifications as soon as
  // the system posts them (the native NotificationListenerService pushes to
  // this channel). Must run before the app UI is built.
  NotificationListenerBridge.instance;

  // Initialise the local notifications plugin (channels, icon, permissions).
  await NotificationService.instance.init();

  // Native pinned-notification bridge (action buttons / body-tap routing).
  PinsBridge.instance;

  // Ask for notification permission early on Android 13+.
  // We do not block the UI on the answer; if denied the editor will ask again
  // when the user actually tries to pin something.
  NotificationService.instance.requestPermission();

  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PinnitApp(),
    ),
  );
  appContainer = container;
}
