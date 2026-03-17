import 'package:flutter/material.dart';

const kPrimaryColor = Color(0xFF40C4FF); // lightBlueAccent equivalent
const kPrimaryDark = Color(0xFF0094CC);

/// Global [ThemeData] for the app.
ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimaryColor,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kPrimaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: kPrimaryColor,
      thumbColor: kPrimaryColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
    ),
    useMaterial3: true,
  );
}
