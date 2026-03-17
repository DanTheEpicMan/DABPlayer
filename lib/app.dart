import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/book_select_screen.dart';
import 'screens/device_position_screen.dart';
import 'screens/player_screen.dart';

class DABPlayerApp extends StatelessWidget {
  const DABPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DABPlayer',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/books': (_) => const BookSelectScreen(),
        '/devices': (_) => const DevicePositionScreen(),
        '/player': (_) => const PlayerScreen(),
      },
    );
  }
}
