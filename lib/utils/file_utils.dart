import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:device_info_plus/device_info_plus.dart';
import '../data/models/book.dart';

/// Resolves and returns the path to the user's Audiobooks directory.
/// Shows permission dialogs and error dialogs as needed via [context].
/// Returns null if the path cannot be determined.
Future<String?> getAudiobooksDirectoryPath(BuildContext? context) async {
  final msgs = <String>[];
  void log(String m) {
    msgs.add(m);
    debugPrint('DABPlayer: $m');
  }

  void showError(String title, String body) {
    if (context == null || !context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  const folderName = 'Audiobooks';

  try {
    if (Platform.isAndroid) {
      log('Android detected');
      final info = await DeviceInfoPlugin().androidInfo;
      final sdk = info.version.sdkInt;
      log('SDK: $sdk');

      bool permsOk = false;
      if (sdk >= 30) {
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          if (context != null && context.mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('Permission Required'),
                content: const Text(
                  "This app needs 'All files access' to read your Audiobooks folder.\n\n"
                  'You will be sent to Settings — find this app and enable '
                  "'All files access'. Then return here.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text("OK, take me to Settings"),
                  ),
                ],
              ),
            );
          }
          await Permission.manageExternalStorage.request();
          status = await Permission.manageExternalStorage.status;
        }
        permsOk = status.isGranted;
      } else {
        permsOk =
            (await Permission.storage.request()) == PermissionStatus.granted;
      }

      if (!permsOk) {
        showError('Permission Denied',
            'Storage access was not granted. Please enable it in App Settings.');
        return null;
      }

      // Derive the public storage root from the app's external path.
      final dirs = await getExternalStorageDirectories();
      if (dirs == null || dirs.isEmpty) {
        showError('Storage Error',
            'Could not locate external storage. Please check your device.');
        return null;
      }
      const marker = '/Android/data/';
      final raw = dirs.first.path;
      final idx = raw.indexOf(marker);
      if (idx == -1) {
        showError('Storage Error', 'Unexpected storage path: $raw');
        return null;
      }
      final root = raw.substring(0, idx);
      final path = p.join(root, folderName);
      final dir = Directory(path);
      if (!await dir.exists()) {
        showError('Folder Not Found',
            "No 'Audiobooks' folder found at: $path\n\nPlease create it and place your MP3 files inside.");
        return null;
      }
      log('Android Audiobooks path: $path');
      return path;
    } else if (Platform.isIOS) {
      final docPath = (await getApplicationDocumentsDirectory()).path;
      final path = p.join(docPath, folderName);
      final dir = Directory(path);
      if (!await dir.exists()) await dir.create(recursive: true);
      log('iOS Audiobooks path: $path');
      return path;
    } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      // Desktop: use ~/Audiobooks
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home == null) {
        showError('Path Error', 'Could not determine home directory.');
        return null;
      }
      final path = p.join(home, folderName);
      final dir = Directory(path);
      if (!await dir.exists()) {
        try {
          await dir.create(recursive: true);
        } catch (e) {
          showError('Folder Error',
              "Could not create '$path'. Please create it manually.");
          return null;
        }
      }
      log('Desktop Audiobooks path: $path');
      return path;
    } else {
      showError('Unsupported Platform', Platform.operatingSystem);
      return null;
    }
  } catch (e, s) {
    log('Exception: $e\n$s');
    showError('Error', 'Could not locate Audiobooks folder: $e');
    return null;
  }
}

/// Scans [dirPath] and returns a sorted list of [Book] objects.
/// Supports single MP3 files and directories of MP3 chapters.
Future<List<Book>> scanAudiobooks(String dirPath) async {
  final dir = Directory(dirPath);
  final entities = await dir.list().toList();
  final books = <Book>[];

  for (final entity in entities) {
    if (entity is File &&
        p.extension(entity.path).toLowerCase() == '.mp3') {
      books.add(Book(
        title: p.basenameWithoutExtension(entity.path),
        id: p.basename(entity.path),
        isChaptered: false,
        chapters: [entity],
      ));
    } else if (entity is Directory) {
      final chapterFiles = await entity
          .list()
          .where((f) =>
              f is File && p.extension(f.path).toLowerCase() == '.mp3')
          .cast<File>()
          .toList();
      if (chapterFiles.isNotEmpty) {
        chapterFiles.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
        books.add(Book(
          title: p.basename(entity.path),
          id: p.basename(entity.path),
          isChaptered: true,
          chapters: chapterFiles,
        ));
      }
    }
  }

  books.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return books;
}
