import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:pinnit_flutter/app.dart';
import 'package:pinnit_flutter/providers.dart';
import 'package:pinnit_flutter/services/blocklist_service.dart';
import 'package:pinnit_flutter/services/notification_listener_bridge.dart';
import 'package:pinnit_flutter/services/notification_service.dart';
import 'package:pinnit_flutter/services/pins_bridge.dart';
import 'package:pinnit_flutter/utils/shader_warmup.dart';

void main() async {
  // 必须在 ensureInitialized() 之前赋值：PaintingBinding 在 initInstances()
  // 里就执行 warm-up，晚了就跑不到。作用是把渐变 / 模糊阴影 / 圆角裁剪这些
  // shader 的现场编译从"第一次弹菜单、第一次进编辑页"挪到启动阶段。
  PaintingBinding.shaderWarmUp = const AppShaderWarmUp();

  WidgetsFlutterBinding.ensureInitialized();

  // Pre-compile the Liquid Glass shaders so the first glass surface renders
  // without a jank spike. Safe to skip (it lazy-loads), but nicer this way.
  await LiquidGlassShaders.ensureLoaded();

  // Load the user's blocklist keywords before the listener bridge starts
  // capturing notifications, so blocked words take effect from the very
  // first notification. If this hasn't finished yet, isBlocked() safely
  // returns false (empty list = nothing blocked).
  await BlocklistService.instance.load();

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
