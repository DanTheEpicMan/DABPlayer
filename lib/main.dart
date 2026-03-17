import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/local_db.dart';
import 'data/repositories/local_repository.dart';
import 'data/repositories/cloud_repository.dart';
import 'data/repositories/sync_manager.dart';
import 'audio/audio_handler.dart';
import 'app.dart';
import 'package:audio_service/audio_service.dart';

// ---------------------------------------------------------------------------
// Global singletons — initialized before runApp
// ---------------------------------------------------------------------------

late AudioHandler audioHandler;
late SyncManager syncManager;
late CloudRepository cloudRepo;

String deviceNameVar = '';
bool cloudEnabled = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Start background audio service (required before runApp on Android)
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.dabplayer.channel.audio',
      androidNotificationChannelName: 'DABPlayer Audio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  // 2. Load user preferences
  final prefs = await SharedPreferences.getInstance();
  deviceNameVar = prefs.getString('deviceName') ?? '';
  cloudEnabled = prefs.getBool('cloudEnabled') ?? false;
  final supabaseUrl = prefs.getString('supabaseUrl') ?? '';
  final supabaseKey = prefs.getString('supabaseAnonKey') ?? '';

  // 3. Initialize storage
  final db = AppDatabase();
  final local = LocalRepository(db);
  cloudRepo = CloudRepository();
  if (cloudEnabled && supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    cloudRepo.configure(supabaseUrl, supabaseKey);
  }
  syncManager = SyncManager(local: local, cloud: cloudRepo);

  runApp(const DABPlayerApp());
}