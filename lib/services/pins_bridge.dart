// Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pinnit_flutter/data/app_database.dart';
import 'package:pinnit_flutter/data/notification_model.dart';
import 'package:pinnit_flutter/editor/editor_screen.dart';
import 'package:pinnit_flutter/providers.dart';
import 'package:pinnit_flutter/repositories/notifications_repository.dart';
import 'package:pinnit_flutter/utils/navigator_key.dart';
import 'package:pinnit_flutter/widgets/app_page_route.dart';

const _kPinsChannel = 'pinnit/pins';

/// Bridges the native [PinnitPins] / [PinnitActionReceiver] layer with Dart.
///
/// * Dart → native: [showPinned] / [cancelPinned] post or remove the system
///   notification. The native side owns the action buttons, so the taps are
///   always delivered (unlike the Flutter plugin's background callback).
/// * native → Dart: `unpin` (user tapped the unpin action in the shade) and
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
      case 'openNewEditor':
        // Launch route from the Quick Settings tile ("new pinned note").
        _openNewEditor();
      case 'prepareNewEditor':
        // Quick Settings tile, sent *before* the Activity is launched (see
        // NewNoteTileService): the engine is already running in the background,
        // so the editor can be pushed while the shade is still collapsing.
        // By the time MainActivity renders its first frame the editor is
        // already on top — no flash of the home screen in between.
        _openNewEditor();
    }
  }

  Future<void> showPinned(PinnitNotification n) async {
    final locale = await _effectiveLocale();
    await _channel.invokeMethod('showPinned', {
      'uuid': n.uuid,
      'title': n.title,
      'content': n.content,
      'locale': locale,
    });
  }

  /// Cached because [showPinned] runs on the save path — hitting
  /// SharedPreferences on every save added avoidable work to the hot path.
  /// Cleared by [invalidateLocale] when the user switches language.
  String? _cachedLocale;

  /// Drop the cached locale (call after a language change).
  void invalidateLocale() => _cachedLocale = null;

  /// Returns the language code that native notification resources should use.
  ///
  /// Respects the in-app language override first, then falls back to the
  /// Flutter platform locale (which follows the system when no override is set).
  /// Defaults to 'en' for any unsupported language so buttons never disappear.
  Future<String> _effectiveLocale() async {
    final cached = _cachedLocale;
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pref = prefs.getString(kLocalePrefKey) ?? 'system';
      String code;
      if (pref == 'system') {
        code = PlatformDispatcher.instance.locale.languageCode;
      } else {
        code = pref;
      }
      final result = code == 'zh' ? 'zh' : 'en';
      _cachedLocale = result;
      return result;
    } catch (_) {
      return 'en';
    }
  }

  Future<void> cancelPinned(String uuid) async {
    await _channel.invokeMethod('cancelPinned', uuid);
  }

  /// 同一波启动只认一次。
  ///
  /// 磁贴会连发两次：一次是 `prepareNewEditor`（Activity 拉起之前），一次是
  /// Activity 起来后带的 `new_note` extra。没有这个窗就会压进两个编辑页。
  DateTime? _lastNewEditorAt;
  int _retries = 0;

  /// 页面是不是已经在用户眼前。
  ///
  /// 决定了跳转用不用动画：app 已经在前台 → 给一段正常的入场动画；
  /// 还在后台（磁贴 / 通知冷启动）→ 直接把页面放好，不让用户看到主界面
  /// 闪一下再跳走。
  bool get _isResumed =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  /// 上一次打开的是哪条通知（配合 [_lastEditorAt] 做去重：MainActivity 会
  /// 重复投递几次，见 invokeOnChannel）。
  String? _lastEditorUuid;
  DateTime? _lastEditorAt;

  void _openEditor(String uuid) {
    final now = DateTime.now();
    final last = _lastEditorAt;
    if (_lastEditorUuid == uuid &&
        last != null &&
        now.difference(last) < const Duration(seconds: 2)) {
      return; // 同一波投递，忽略。
    }
    final state = navigatorKey.currentState;
    if (state != null) {
      _retries = 0;
      _lastEditorUuid = uuid;
      _lastEditorAt = now;
      state.push(
        AppPageRoute(
          builder: (_) => EditorScreen(uuid: uuid),
          instant: !_isResumed,
        ),
      );
    } else if (_retries < 40) {
      // UI not mounted yet (cold start via body tap) — retry at a short
      // interval so the editor lands as early as possible.
      _retries++;
      Future.delayed(const Duration(milliseconds: 50), () => _openEditor(uuid));
    }
  }

  /// Quick Settings tile launch: a blank editor (new note).
  void _openNewEditor() {
    final now = DateTime.now();
    final last = _lastNewEditorAt;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      return; // 同一波启动，已经压过了。
    }
    final state = navigatorKey.currentState;
    if (state != null) {
      _retries = 0;
      _lastNewEditorAt = now;
      state.push(
        AppPageRoute(
          builder: (_) => const EditorScreen(),
          instant: !_isResumed,
        ),
      );
    } else if (_retries < 40) {
      _retries++;
      Future.delayed(const Duration(milliseconds: 50), _openNewEditor);
    }
  }
}
