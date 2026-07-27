import 'package:flutter/material.dart';

/// Light/Dark Material 3 themes for the Pinnit clone.
class PinnitTheme {
  static const _seed = Color(0xFF6750A4);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _seed,
        brightness: Brightness.light,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _seed,
        brightness: Brightness.dark,
      );
}
