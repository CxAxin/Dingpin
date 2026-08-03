// Pinnit (Flutter port) — derivative work of Pinnit (https://github.com/msasikanth/pinnit).
// Original © 2020 Sasikanth Miriyampalli, Apache-2.0. Modified. See LICENSE and NOTICE.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinnit_flutter/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pinnit_flutter/data/app_database.dart';
import 'package:pinnit_flutter/home/main_screen.dart';
import 'package:pinnit_flutter/providers.dart';
import 'package:pinnit_flutter/services/notification_service.dart';
import 'package:pinnit_flutter/theme/theme.dart';
import 'package:pinnit_flutter/utils/navigator_key.dart';

class PinnitApp extends ConsumerStatefulWidget {
  const PinnitApp({super.key});

  @override
  ConsumerState<PinnitApp> createState() => _PinnitAppState();
}

class _PinnitAppState extends ConsumerState<PinnitApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restorePinnedNotifications();
    _loadLocalePreference();
  }

  Future<void> _loadLocalePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(kLocalePrefKey);
      if (mounted) {
        ref.read(localeOverrideProvider.notifier).state =
            localeFromPreference(value);
      }
    } catch (_) {
      // Ignore — language simply stays at the default (follow system).
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-post pinned notifications whenever the app returns to the foreground,
  /// not just on cold start. This covers the case where the OS/OEM killed the
  /// process while it was in the background — reopening the app restores the
  /// pins reliably. The call is idempotent (stable notification ids), so it
  /// never creates duplicates.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restorePinnedNotifications();
    }
  }

  /// Re-post every pinned notification when the app starts. This covers two
  /// common cases:
  ///
  /// 1. The user swiped away all notifications and then reopened the app.
  /// 2. The process was killed by the system/OEM and is now restarting.
  Future<void> _restorePinnedNotifications() async {
    try {
      final pinned = await AppDatabase.pinnedNotifications();
      if (pinned.isEmpty) return;
      for (final n in pinned) {
        await NotificationService.instance.showPinned(n);
      }
    } catch (e, st) {
      debugPrint('restore pinned failed: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    // A simple in-memory theme mode toggle. Persisted theme is Phase 2.
    final themeMode = ref.watch(themeModeProvider);
    final localeOverride = ref.watch(localeOverrideProvider);

    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'Dingpin',
      debugShowCheckedModeBanner: false,
      // `null` lets Flutter follow the system locale; a non-null value is the
      // user's manual override (set from the About screen, persisted).
      locale: localeOverride,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh'),
        Locale('en'),
      ],
      theme: PinnitTheme.light,
      darkTheme: PinnitTheme.dark,
      themeMode: themeMode,
      navigatorKey: navigatorKey,
      home: const MainScreen(),
    );
  }
}
