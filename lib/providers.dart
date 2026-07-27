import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:pinnit_flutter/repositories/third_party_repository.dart'
    show thirdPartyProvider;

/// Global theme-mode toggle (system / light / dark).
///
/// Persisted theme is tracked as a Phase 2 follow-up; for now it lives in
/// memory so the in-app toggle works during a session.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Global [ProviderContainer] so non-widget singletons (e.g. [PinsBridge])
/// can refresh providers in response to system / notification events.
late ProviderContainer appContainer;
