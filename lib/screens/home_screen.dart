import 'package:flutter/material.dart';
import '../main.dart';
import '../audio/audio_handler.dart';

/// Splash screen that decides where to route based on app state.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (deviceNameVar.isEmpty) {
        Navigator.pushReplacementNamed(context, '/settings');
        return;
      }
      if (currentBook == null) {
        Navigator.pushReplacementNamed(context, '/books');
        return;
      }
      Navigator.pushReplacementNamed(context, '/player');
    });

    return const Scaffold(
      backgroundColor: Color(0xFF40C4FF),
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
