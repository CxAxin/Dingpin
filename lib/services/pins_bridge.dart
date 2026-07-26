// Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pinnit_flutter/data/app_database.dart';
import 'package:pinnit_flutter/data/notification_model.dart';
import 'package:pinnit_flutter/editor/editor_screen.dart';
import 'package:pinnit_flutter/providers.dart';
import 'package:pinnit_flutter/repositories/notifications_repository.dart';
import 'package:pinnit_flutter/utils/navigator_key.dart';

const _kPinsChannel = 'pinnit/pins';

/// Bridges the native [PinnitPins] / [PinnitActionReceiver] layer with Dart.
///
/// * Dart → native: [showPinned] / [cancelPinned] post or remove the system
///   notification. The native side owns the action buttons, so the taps are
///   always delivered (unlike the Flutter plugin's background callback).
/// * native → Dart: `unpin` (user tapped "取消固定" in the shade) and
///   `openEditor` (user tapped the notification body) are handled here.
class PinsBridge {
  PinsBridge._() {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static final PinsBridge instance = PinsBridge._();

  final MethodChannel _channel = const MethodChannel(_kPinsChannel);

  Future<void> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'unpin':
        final uuid = call.arguments as String?;
        if (uuid != null) {
          await AppDatabase.updatePinStatus(uuid, false);
          // Cancel on the native side; the listener then fires repinAll, but
          // the DB already says "unpinned" so it won't reappear.
          await PinsBridge.instance.cancelPinned(uuid);
          try {
            appContainer.read(notificationsProvider.notifier).refresh();
          } catch (_) {}
        }
      case 'openEditor':
        final uuid = call.arguments as String?;
        if (uuid != null) _openEditor(uuid);
    }
  }

  Future<void> showPinned(PinnitNotification n) async {
    await _channel.invokeMethod('showPinned', {
      'uuid': n.uuid,
      'title': n.title,
      'content': n.content,
    });
  }

  Future<void> cancelPinned(String uuid) async {
    await _channel.invokeMethod('cancelPinned', uuid);
  }

  void _openEditor(String uuid) {
    final state = navigatorKey.currentState;
    if (state != null) {
      state.push(MaterialPageRoute(builder: (_) => EditorScreen(uuid: uuid)));
    } else {
      // UI not mounted yet (cold start via body tap) — retry shortly.
      Future.delayed(const Duration(milliseconds: 400), () => _openEditor(uuid));
    }
  }
}
