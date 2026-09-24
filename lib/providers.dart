import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:pinnit_flutter/repositories/third_party_repository.dart'
    show thirdPartyProvider, HistoryState, ThirdPartyNotifier;

/// Global theme-mode toggle (system / light / dark).
///
/// Persisted theme is tracked as a Phase 2 follow-up; for now it lives in
/// memory so the in-app toggle works during a session.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// User's language override. `null` means follow the system locale.
final localeOverrideProvider = StateProvider<Locale?>((ref) => null);

/// Persisted key used with `shared_preferences` for the language choice.
const kLocalePrefKey = 'locale_preference';

/// Maps the persisted preference string to a [Locale] override.
///
/// `null` (or "system") means follow the system; "zh"/"en" force a language.
Locale? localeFromPreference(String? value) {
  switch (value) {
    case 'zh':
      return const Locale('zh');
    case 'en':
      return const Locale('en');
    default:
      return null;
  }
}

/// Serializes a [Locale] override back to the preference string.
String localePreferenceValue(Locale? locale) {
  if (locale == null) return 'system';
  return locale.languageCode == 'zh' ? 'zh' : 'en';
}

/// Global [ProviderContainer] so non-widget singletons (e.g. [PinsBridge])
/// can refresh providers in response to system / notification events.
late ProviderContainer appContainer;

/// True while a swipe-delete undo banner is on screen.
///
/// The banner sits just above the glass tab bar, which is exactly where the
/// "new pin" FAB floats, so [MainScreen] tucks the FAB away for the few
/// seconds the banner is visible instead of letting them overlap.
final undoBannerVisibleProvider = StateProvider<bool>((ref) => false);
