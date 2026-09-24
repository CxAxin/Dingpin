import 'package:flutter/material.dart';

/// Light/Dark Material 3 themes for the Pinnit clone.
///
/// Warm "paper & sunlight" seed (Wonderous-style editorial warmth): a warm
/// amber-brown seed keeps every generated M3 color in the same warm family as
/// the parchment backdrop, instead of the old purple seed fighting it.
/// AppBar titles use a serif font for the magazine feel; body stays sans.
class PinnitTheme {
  static const _seed = Color(0xFF8A6D3B); // warm amber-brown

  static const _serif = 'serif';

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _seed,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            fontFamily: _serif,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: Color(0xFF3B3226),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _seed,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            fontFamily: _serif,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: Color(0xFFEDE4D3),
          ),
        ),
      );
}
