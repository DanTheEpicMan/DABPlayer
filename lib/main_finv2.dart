import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; // For Directory, File, AND Platform
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p; // For path manipulation
import 'package:pantry/pantry.dart'; // Assuming this is your Pantry client library
import 'dart:async'; // For Future.value and StreamSubscription

import 'package:audioplayers/audioplayers.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';

// =========================================================================
// ==================== NEW DATA MODEL AND GLOBAL STATE ====================
// =========================================================================

/// Represents a single audiobook, which can be a single file or a collection of chapters.
class Book {
  final String title;
  final String pantryKey; // Folder name for chaptered, full MP3 filename for single.
  final bool isChaptered;
  final List<File> chapters; // List of MP3 files, sorted alphabetically.

  Book({
    required this.title,
    required this.pantryKey,
    required this.isChaptered,
    required this.chapters,
  });
}

// Global variables
String keyVar = '';
String basketVar = '';
String deviceNameVar = '';

// NEW: These variables define the currently active book and the user's position within it.
Book? currentBook;
int currentChapterIndex = 0;
double currentTimestamp = -1; // Timestamp in seconds for the current chapter.

// DEPRECATED-IN-SPIRIT: `currMP3` is now just a convenient alias for the book's unique Pantry key.
// It should NOT be used to reference a file path directly.
String get currMP3 => currentBook?.pantryKey ?? '';

Pantry? locPan;


// --- Global Pantry Helper Functions ---

/// Updates the timestamp in Pantry. Now includes chapter information.
Future<void> _updatePantryTimestampGlobal(int chapterIndex, double positionInSeconds) async {
  if (locPan == null || currMP3.isEmpty || deviceNameVar.isEmpty || basketVar.isEmpty) {
    print("Pantry update timestamp: Missing required global variables.");
    return;
  }
  try {
    var basketData = await locPan!.getBasket(basketVar);
    basketData ??= {};

    if (!basketData.containsKey(currMP3)) {
      basketData[currMP3] = {'Notes': [], 'Devices': []};
    }
    Map<String, dynamic> mp3Entry = Map<String, dynamic>.from(basketData[currMP3]);
    mp3Entry['Devices'] ??= [];
    mp3Entry['Notes'] ??= [];

    List<dynamic> devicesList = List<dynamic>.from(mp3Entry['Devices']);
    int deviceIndex = devicesList.indexWhere((d) => d is Map && d.containsKey(deviceNameVar));

    // NEW: The position is now a map containing chapter and timestamp.
    final positionMap = {'chapter': chapterIndex, 'position': positionInSeconds};

    if (deviceIndex != -1) {
      (devicesList[deviceIndex] as Map)[deviceNameVar] = positionMap;
    } else {
      devicesList.add({deviceNameVar: positionMap});
    }
    mp3Entry['Devices'] = devicesList;
    basketData[currMP3] = mp3Entry;

    await locPan!.newBasket(basketVar, basketData);
    print("Pantry timestamp updated for $deviceNameVar in $currMP3 to Chapter ${chapterIndex + 1} @ ${positionInSeconds}s.");
  } catch (e, s) {
    print("Error updating Pantry timestamp: $e\n$s");
  }
}

Future<void> _updatePantryNotesGlobal(List<String> notes) async {
  if (locPan == null || currMP3.isEmpty || basketVar.isEmpty) {
    print("Pantry update notes: Missing required global variables.");
    return;
  }
  try {
    var basketData = await locPan!.getBasket(basketVar);
    basketData ??= {};
    if (!basketData.containsKey(currMP3)) {
      basketData[currMP3] = {'Notes': [], 'Devices': []};
    }
    Map<String, dynamic> mp3Entry = Map<String, dynamic>.from(basketData[currMP3]);
    mp3Entry['Devices'] ??= [];
    mp3Entry['Notes'] = notes;
    basketData[currMP3] = mp3Entry;
    await locPan!.newBasket(basketVar, basketData);
    print("Pantry notes updated for $currMP3.");
  } catch (e, s) {
    print("Error updating Pantry notes: $e\n$s");
  }
}
// --- End Global Pantry Helper Functions ---


Future<void> getENVVars() async {
  final prefs = await SharedPreferences.getInstance();
  keyVar = prefs.getString('apiKey') ?? '';
  basketVar = prefs.getString('basketName') ?? '';
  deviceNameVar = prefs.getString('deviceName') ?? '';
}

Future<void> setENVVars(String kv, String bn, String dn) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('apiKey', kv);
  await prefs.setString('basketName', bn);
  await prefs.setString('deviceName', dn);
}

Future<bool> _tryCreateDir(Directory dir, Function(String) logger) async {
  try {
    logger("Trying to create dir: ${dir.path}");
    await dir.create(recursive: true);
    logger("Successfully created directory (or it already existed): ${dir.path}");
    return true;
  } catch (e) {
    logger("Could not create directory ${dir.path}: $e");
    return false;
  }
}

Future<String?> getAudiobooksDirectoryPath(BuildContext? contextForMessages) async {
  Directory? directory;
  String customFolderName = "Audiobooks";
  String? finalPath;
  List<String> debugMessages = [];
  bool isShowingPermissionDialog = false;

  void _showDebugPopup(String title, String content, {bool isError = true}) {
    debugMessages.add("$title: $content");
    print("DEBUG POPUP - $title: $content");
    if (contextForMessages != null && contextForMessages.mounted && !isShowingPermissionDialog) {
      isShowingPermissionDialog = true;
      showDialog(
        context: contextForMessages,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text("OK"),
            )
          ],
        ),
      ).then((_) {
        isShowingPermissionDialog = false;
      });
    }
  }

  void _logDebug(String message) {
    debugMessages.add(message);
    print("DEBUG LOG: $message");
  }

  _logDebug("Starting getAudiobooksDirectoryPath...");

  try {
    if (Platform.isAndroid) {
      _logDebug("Platform is Android. Checking permissions...");

      AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      int sdkInt = androidInfo.version.sdkInt;
      _logDebug("Android SDK Int: $sdkInt");

      bool hasSufficientPermissions = false;

      if (sdkInt >= 30) {
        _logDebug("SDK >= 30. Focusing on MANAGE_EXTERNAL_STORAGE.");
        PermissionStatus manageStatus = await Permission.manageExternalStorage.status;
        _logDebug("Initial Permission.manageExternalStorage status: ${manageStatus.name}");

        if (!manageStatus.isGranted) {
          _logDebug("MANAGE_EXTERNAL_STORAGE not granted. Will show explanatory dialog then request.");
          if (contextForMessages != null && contextForMessages.mounted && !isShowingPermissionDialog) {
            isShowingPermissionDialog = true;
            await showDialog(
                context: contextForMessages,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  title: const Text("Permission Required"),
                  content: const Text(
                      "This app needs 'All files access' to read your 'Audiobooks' folder from the main storage.\n\n"
                          "You will be taken to your phone's settings. Please find this app, go to its permissions, and enable 'All files access' (or 'Files and Media' -> 'Allow management of all files'). Then, return to the app."),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text("OK, take me to Settings")
                    )
                  ],
                )
            ).then((_) async {
              isShowingPermissionDialog = false;
              _logDebug("Explanatory dialog dismissed. Now requesting Permission.manageExternalStorage...");
              await Permission.manageExternalStorage.request();
              hasSufficientPermissions = await Permission.manageExternalStorage.status == PermissionStatus.granted;
              if (!hasSufficientPermissions) {
                _logDebug("MANAGE_EXTERNAL_STORAGE was still not granted after settings trip.");
                _showDebugPopup("Permission Denied", "MANAGE_EXTERNAL_STORAGE (All files access) was not granted. This is required. Please grant it manually in App Settings for this app, then try again.", isError: true);
              } else {
                _logDebug("MANAGE_EXTERNAL_STORAGE appears to be granted after settings trip.");
              }
            });
            if (await Permission.manageExternalStorage.status == PermissionStatus.granted) {
              hasSufficientPermissions = true;
            }
          } else {
            _logDebug("Context not available or dialog already showing, cannot show explanatory dialog for MANAGE_EXTERNAL_STORAGE.");
            await Permission.manageExternalStorage.request();
            hasSufficientPermissions = await Permission.manageExternalStorage.status == PermissionStatus.granted;
            if (!hasSufficientPermissions) _logDebug("Direct request for MANAGE_EXTERNAL_STORAGE failed.");
          }
        } else {
          _logDebug("MANAGE_EXTERNAL_STORAGE was already granted.");
          hasSufficientPermissions = true;
        }
      } else {
        _logDebug("SDK < 30. Requesting legacy Permission.storage.");
        PermissionStatus storageStatus = await Permission.storage.request();
        _logDebug("After request, Permission.storage status: ${storageStatus.name}");
        hasSufficientPermissions = storageStatus.isGranted;
        if (!hasSufficientPermissions) {
          _logDebug("Legacy storage permissions were not granted for SDK < 30.");
        }
      }

      if (hasSufficientPermissions) {
        _logDebug("Sufficient storage permissions appear granted. Attempting to find public shared storage root...");

        String? publicRootPath;
        try {
          List<Directory>? allExternalDirs = await getExternalStorageDirectories(type: null);

          if (allExternalDirs != null && allExternalDirs.isNotEmpty) {
            _logDebug("Available external directories from getExternalStorageDirectories(type: null):");
            for (var dir in allExternalDirs) { _logDebug("- ${dir.path}"); }

            final primaryPath = allExternalDirs.first.path;
            const androidDataMarker = '/Android/data/';
            final dataIndex = primaryPath.indexOf(androidDataMarker);

            if (dataIndex != -1) {
              publicRootPath = primaryPath.substring(0, dataIndex);
              _logDebug("Successfully derived public root from path_provider: $publicRootPath");
            } else {
              _logDebug("Could not find '$androidDataMarker' in path. This is unexpected. Using the first path as-is: $primaryPath. The 'Audiobooks' folder might not be found.");
              publicRootPath = null;
            }
          }
        } catch (e, s) {
          _logDebug("Error getting external storage directories: $e\n$s");
        }

        if (publicRootPath != null) {
          _logDebug("Using determined public root path: $publicRootPath");

          finalPath = p.join(publicRootPath, customFolderName);
          directory = Directory(finalPath);
          _logDebug("Targeting custom path: $finalPath");

          if (!await directory.exists()) {
            _logDebug("ERROR: Target Android directory $finalPath does NOT exist.");
            _showDebugPopup("Folder Not Found",
                "The 'Audiobooks' folder was not found at the expected location: $finalPath\n\n"
                    "Please ensure this folder exists in the root of your phone's internal shared storage and contains your MP3 files.",
                isError: true);
            return null;
          } else {
            _logDebug("Target Android directory $finalPath exists.");
          }
        } else {
          _logDebug("Could not determine a suitable public external storage root path.");
          _showDebugPopup("Storage Root Error", "Could not determine the primary external storage root. Cannot locate 'Audiobooks' folder.\nDebug Log:\n${debugMessages.join('\n')}", isError: true);
          return null;
        }
      } else {
        _logDebug("ERROR: Sufficient storage permissions were ultimately denied or not obtained. SDK: $sdkInt");
        if (!isShowingPermissionDialog) {
          _showDebugPopup("Permissions Issue", "Could not obtain necessary storage permissions. Please check previous messages or app settings.\nSDK: $sdkInt\nDebug Log:\n${debugMessages.join('\n')}", isError: true);
        }
        return null;
      }
    } else if (Platform.isIOS) {
      _logDebug("Platform is iOS.");
      String docPath = (await getApplicationDocumentsDirectory()).path;
      finalPath = p.join(docPath, customFolderName);
      directory = Directory(finalPath);
      _logDebug("iOS: Targeting path in app documents: $finalPath");
      if (!await directory.exists()) {
        if (!await _tryCreateDir(directory, _logDebug)){
          _showDebugPopup("iOS Error", "Could not create 'Audiobooks' folder in app documents: $finalPath", isError: true);
          return null;
        }
      }
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      _logDebug("Platform is Desktop.");
      Directory? primaryDir;
      try {
        primaryDir = await getApplicationDocumentsDirectory();
        if (primaryDir != null) {
          finalPath = p.join(primaryDir.path, customFolderName);
          directory = Directory(finalPath);
          _logDebug("Desktop: Using Documents dir: $finalPath");
        }
      } catch(e) {
        _logDebug("Desktop: Could not get Documents directory: $e. Trying Downloads.");
        primaryDir = null;
      }

      bool desktopDirOk = false;
      if (directory != null) {
        if (await directory.exists()) {
          desktopDirOk = true;
        } else {
          if (await _tryCreateDir(directory, _logDebug)) {
            desktopDirOk = true;
          }
        }
      }

      if (primaryDir == null || !desktopDirOk) {
        _logDebug("Desktop: Documents dir failed or not usable. Trying Downloads.");
        try {
          primaryDir = await getDownloadsDirectory();
          if (primaryDir != null) {
            finalPath = p.join(primaryDir.path, customFolderName);
            directory = Directory(finalPath);
            _logDebug("Desktop: Using Downloads dir: $finalPath");
            if (await directory.exists()) {
              desktopDirOk = true;
            } else {
              if (await _tryCreateDir(directory, _logDebug)) {
                desktopDirOk = true;
              }
            }
          } else {
            _logDebug("Desktop: ERROR: Could not get Downloads directory either.");
            desktopDirOk = false;
          }
        } catch (e) {
          _logDebug("Desktop: ERROR getting Downloads directory (fallback): $e");
          desktopDirOk = false;
        }
      }
      if (!desktopDirOk) {
        _showDebugPopup("Desktop Error", "Could not access or create Audiobooks folder in Documents or Downloads.\nDebug Log:\n${debugMessages.join('\n')}", isError: true);
        return null;
      }
    } else {
      _logDebug("ERROR: Unsupported platform: ${Platform.operatingSystem}");
      _showDebugPopup("Platform Error", "Unsupported operating system: ${Platform.operatingSystem}", isError: true);
      return null;
    }

    if (directory != null && finalPath != null) {
      if (!await directory.exists()) {
        _logDebug("Error: Directory $finalPath reported as non-existent at final check.");
        _showDebugPopup("Path Error", "The Audiobooks folder at $finalPath could not be confirmed.", isError: true);
        return null;
      }
      _logDebug("SUCCESS: Using directory: ${directory.path}");
      return directory.path;
    } else {
      _logDebug("ERROR: Directory or finalPath is null at the end of all logic. This is an internal error in path resolution.");
      _showDebugPopup("Internal Path Error", "Could not resolve a valid directory path due to an internal logic error.\nDebug Log:\n${debugMessages.join('\n')}", isError: true);
      return null;
    }
  } catch (e, s) {
    _logDebug("CRITICAL EXCEPTION in getAudiobooksDirectoryPath: $e\nStack trace:\n$s");
    _showDebugPopup("Critical Function Exception",
        "An unexpected exception occurred within the getAudiobooksDirectoryPath function: $e\n\nStack Trace:\n$s\n\nDebug Log:\n${debugMessages.join('\n')}",
        isError: true);
  }
  _logDebug("Finished getAudiobooksDirectoryPath, returning null due to an earlier error or unhandled path.");
  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await getENVVars();
  if (keyVar.isNotEmpty) {
    locPan = Pantry(keyVar);
  }

  runApp(MaterialApp(
    initialRoute: '/',
    routes: {
      '/': (context) => const HomeRoute(),
      '/settings': (context) => const Settings(),
      '/ABSelect': (context) => const ABSelect(),
      '/DeviceSelect': (context) => const DeviceSelect(),
      '/main': (context) => const Main(),
    },
    debugShowCheckedModeBanner: false,
  ));
}

class HomeRoute extends StatelessWidget {
  const HomeRoute({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      if (keyVar.isEmpty || basketVar.isEmpty || deviceNameVar.isEmpty) {
        if (ModalRoute.of(context)?.settings.name != '/settings') {
          Navigator.pushReplacementNamed(context, '/settings');
        }
        return;
      }

      if (locPan == null && keyVar.isNotEmpty) {
        locPan = Pantry(keyVar);
      }

      if (currentBook == null || currMP3.isEmpty || currentTimestamp == -1) {
        if (ModalRoute.of(context)?.settings.name != '/ABSelect') {
          Navigator.pushReplacementNamed(context, '/ABSelect');
        }
        return;
      }

      if (ModalRoute.of(context)?.settings.name != '/main') {
        Navigator.pushReplacementNamed(context, '/main');
      }
    });

    return const Scaffold(
      backgroundColor: Colors.lightBlueAccent,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _apiKeyController;
  late TextEditingController _basketNameController;
  late TextEditingController _deviceNameController;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: keyVar);
    _basketNameController = TextEditingController(text: basketVar);
    _deviceNameController = TextEditingController(text: deviceNameVar);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _basketNameController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.lightBlueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: <Widget>[
              const Text(
                "This app requires a connection to Pantry, an online JSON storing API.\n"
                    "On your web-browser go to https://getpantry.cloud/.\n"
                    "1. Create an account, save the Pantry ID (API Key) it gives you below.\n"
                    "2. Create a basket with some name, save the name below.\n"
                    "3. Create a device name below. This name identifies your current device.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(labelText: "Pantry ID (API Key from Pantry website):"),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) return "Cannot be empty";
                  return null;
                },
              ),
              TextFormField(
                controller: _basketNameController,
                decoration: const InputDecoration(labelText: "Basket Name (created on Pantry website):"),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) return "Cannot be empty";
                  return null;
                },
              ),
              TextFormField(
                controller: _deviceNameController,
                decoration: const InputDecoration(labelText: "Current Device Name (e.g., My Phone):"),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) return "Cannot be empty";
                  return null;
                },
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final String apiKey = _apiKeyController.text.trim();
                    final String basketName = _basketNameController.text.trim();
                    final String deviceName = _deviceNameController.text.trim();

                    await setENVVars(apiKey, basketName, deviceName);

                    keyVar = apiKey;
                    basketVar = basketName;
                    deviceNameVar = deviceName;

                    locPan = Pantry(keyVar);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings saved!')),
                      );
                      Navigator.pushReplacementNamed(context, '/');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlueAccent, foregroundColor: Colors.white),
                child: const Text('Save Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ABSelect extends StatefulWidget {
  const ABSelect({Key? key}) : super(key: key);

  @override
  _ABSelectState createState() => _ABSelectState();
}

class _ABSelectState extends State<ABSelect> {
  List<Book> _books = [];
  String? _audiobooksPath;
  bool _isLoading = true;
  String _errorMessage = '';
  String _debugLoadMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAudiobooks();
  }

  /// NEW: This method now scans for both loose .mp3 files and directories.
  Future<void> _loadAudiobooks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _debugLoadMessage = 'Starting audiobook scan...\n';
      _books = [];
    });

    _audiobooksPath = await getAudiobooksDirectoryPath(context);

    if (_audiobooksPath == null) {
      setState(() {
        _errorMessage = "Could not access or create Audiobooks directory. Check permissions and restart app.";
        _isLoading = false;
      });
      return;
    }

    try {
      final dir = Directory(_audiobooksPath!);
      if (!await dir.exists()){
        setState(() {
          _errorMessage = "Audiobooks directory does not exist: $_audiobooksPath. Please create it or check path.";
          _isLoading = false;
        });
        return;
      }

      final List<FileSystemEntity> entities = await dir.list().toList();
      _debugLoadMessage += 'Found ${entities.length} items in Audiobooks folder.\n';
      final List<Book> foundBooks = [];

      for (var entity in entities) {
        if (entity is File && p.extension(entity.path).toLowerCase() == '.mp3') {
          _debugLoadMessage += 'Found single MP3 book: ${p.basename(entity.path)}\n';
          foundBooks.add(Book(
            title: p.basenameWithoutExtension(entity.path),
            pantryKey: p.basename(entity.path),
            isChaptered: false,
            chapters: [entity],
          ));
        } else if (entity is Directory) {
          _debugLoadMessage += 'Found directory, checking for chapters: ${p.basename(entity.path)}\n';
          final List<File> chapterFiles = [];
          final chapterEntities = await entity.list().toList();
          for (var chapterEntity in chapterEntities) {
            if (chapterEntity is File && p.extension(chapterEntity.path).toLowerCase() == '.mp3') {
              chapterFiles.add(chapterEntity);
            }
          }

          if (chapterFiles.isNotEmpty) {
            chapterFiles.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
            _debugLoadMessage += ' -> Found ${chapterFiles.length} chapters. Creating chaptered book.\n';
            foundBooks.add(Book(
              title: p.basename(entity.path),
              pantryKey: p.basename(entity.path),
              isChaptered: true,
              chapters: chapterFiles,
            ));
          } else {
            _debugLoadMessage += ' -> No MP3s found in directory. Ignoring.\n';
          }
        }
      }

      foundBooks.sort((a, b) => a.title.compareTo(b.title));
      _debugLoadMessage += 'Scan complete. Found ${foundBooks.length} total books.\n';
      print(_debugLoadMessage);

      setState(() {
        _books = foundBooks;
        _isLoading = false;
      });

    } catch (e, s) {
      print("Error loading audiobooks: $e\n$s");
      setState(() {
        _errorMessage = "Error loading audiobooks: $e";
        _debugLoadMessage += "\nCRITICAL ERROR: $e\n$s";
        _isLoading = false;
      });
      _showDebugDialog(); // Show debug info on critical error
    }
  }

  void _showDebugDialog() {
    if (!context.mounted) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Book Loading Debug Info"),
      content: SingleChildScrollView(child: Text(_debugLoadMessage)),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Close"))],
    ));
  }

  void _selectAudiobook(Book book) {
    currentBook = book;
    currentChapterIndex = 0;
    currentTimestamp = 0.0; // Default to start
    print("Selected Book: ${book.title} (Pantry Key: ${book.pantryKey}). Initial position set to Chapter 1 at 0s.");
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/DeviceSelect');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Audiobook"),
        backgroundColor: Colors.lightBlueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAudiobooks,
            tooltip: "Refresh List",
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              if (context.mounted) Navigator.pushReplacementNamed(context, '/settings');
            },
            tooltip: "Go to settings",
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_audiobooksPath != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Audiobooks folder:\n$_audiobooksPath",
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_errorMessage.isNotEmpty)
            Expanded(
                child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    )))
          else if (_books.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _audiobooksPath != null
                          ? "No MP3 files or valid chapter folders found in '$_audiobooksPath'.\nEnsure MP3s end with '.mp3'."
                          : "Could not determine Audiobooks directory.",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _books.length,
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    return ListTile(
                      leading: Icon(book.isChaptered ? Icons.folder : Icons.music_note, color: Colors.lightBlueAccent),
                      title: Text(book.title),
                      subtitle: Text(book.isChaptered ? "${book.chapters.length} chapters" : book.pantryKey),
                      onTap: () => _selectAudiobook(book),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}

/// Represents a parsed device position from Pantry.
class DevicePosition {
  final String deviceName;
  final int chapterIndex;
  final double timestamp;

  DevicePosition({required this.deviceName, this.chapterIndex = 0, this.timestamp = 0.0});
}

class DeviceSelect extends StatefulWidget {
  const DeviceSelect({Key? key}) : super(key: key);

  @override
  _DeviceSelectState createState() => _DeviceSelectState();
}

class _DeviceSelectState extends State<DeviceSelect> {
  Future<List<DevicePosition>?>? _devicesFuture;
  String _debugInfoOnError = '';

  @override
  void initState() {
    super.initState();
    _initializeAndFetchData();
  }

  void _initializeAndFetchData() {
    _debugInfoOnError = '';
    if (keyVar.isEmpty || locPan == null) {
      _debugInfoOnError = "Error: Pantry API key or client (locPan) is not initialized.\n"
          "API Key Empty: ${keyVar.isEmpty}\n"
          "locPan is null: ${locPan == null}";
      print(_debugInfoOnError);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Pantry client not ready. Go to settings."), duration: Duration(seconds: 3)),
          );
          Navigator.pushReplacementNamed(context, '/settings');
        }
      });
      setState(() {
        _devicesFuture = Future.value(null);
      });
      return;
    }
    setState(() {
      _devicesFuture = _getListOfDevicesAndPositionsWithCreation();
    });
  }

  // NEW: Parses both the old (double) and new (map) position formats.
  DevicePosition _parseDevicePosition(String deviceName, dynamic positionData) {
    if (positionData is Map) {
      // New format: {'chapter': 1, 'position': 123.45}
      int chapter = (positionData['chapter'] as num?)?.toInt() ?? 0;
      double position = (positionData['position'] as num?)?.toDouble() ?? 0.0;
      return DevicePosition(deviceName: deviceName, chapterIndex: chapter, timestamp: position);
    } else if (positionData is num) {
      // Old format (double). Assume it's chapter 0 for single-file books.
      return DevicePosition(deviceName: deviceName, chapterIndex: 0, timestamp: positionData.toDouble());
    }
    // Default fallback
    return DevicePosition(deviceName: deviceName);
  }

  List<DevicePosition> _parseDevicesFromData(dynamic devicesListRaw) {
    List<DevicePosition> parsedList = [];
    if (devicesListRaw is List) {
      for (var deviceEntry in devicesListRaw) {
        if (deviceEntry is Map<String, dynamic> && deviceEntry.isNotEmpty) {
          String deviceName = deviceEntry.keys.first;
          dynamic position = deviceEntry.values.first;
          parsedList.add(_parseDevicePosition(deviceName, position));
        }
      }
    }
    return parsedList;
  }

  Future<List<DevicePosition>?> _getListOfDevicesAndPositionsWithCreation() async {
    _debugInfoOnError = "Starting data fetch for DeviceSelect...\n";
    _debugInfoOnError += "locPan available: ${locPan != null}\n";
    _debugInfoOnError += "Basket Variable: '$basketVar'\n";
    _debugInfoOnError += "Current Book Pantry Key: '$currMP3'\n";
    _debugInfoOnError += "Current Device Name: '$deviceNameVar'\n";

    if (locPan == null) {
      _debugInfoOnError += "Error: locPan is null. Cannot fetch from Pantry.\n";
      print("Error in DeviceSelect: locPan is null.");
      return Future.error(StateError("Pantry client (locPan) is null."));
    }
    if (currMP3.isEmpty) {
      _debugInfoOnError += "Error: currMP3 is empty. No book selected.\n";
      print("Error in DeviceSelect: currMP3 is empty.");
      if (mounted) Navigator.pushReplacementNamed(context, '/ABSelect');
      return Future.value([]);
    }
    if (basketVar.isEmpty) {
      _debugInfoOnError += "Error: basketVar is empty. Cannot fetch from Pantry.\n";
      print("Error in DeviceSelect: basketVar is empty.");
      return Future.error(StateError("Pantry basket name (basketVar) is empty."));
    }


    try {
      _debugInfoOnError += "Attempting to get basket: '$basketVar' from Pantry...\n";
      Map<String, dynamic>? basketContent = await locPan!.getBasket(basketVar);
      _debugInfoOnError += "Pantry getBasket call completed.\n";
      _debugInfoOnError += "Basket content received: ${basketContent == null ? 'null' : 'has data (keys: ${basketContent.keys.toList()})'}\n";

      basketContent ??= {};

      bool modified = false;
      Map<String, dynamic> workingBasketContent = Map<String, dynamic>.from(basketContent);

      // New: The default position is now a map.
      final defaultPosition = {'chapter': 0, 'position': 0.0};

      if (!workingBasketContent.containsKey(currMP3)) {
        _debugInfoOnError += "Pantry key '$currMP3' not found in basket. Creating entry with current device '$deviceNameVar'.\n";
        workingBasketContent[currMP3] = {
          "Notes": [],
          "Devices": [ {deviceNameVar: defaultPosition} ]
        };
        modified = true;
      } else {
        Map<String, dynamic> mp3Data = Map<String, dynamic>.from(workingBasketContent[currMP3]);
        _debugInfoOnError += "Pantry key '$currMP3' found. MP3 Data: $mp3Data\n";
        mp3Data['Notes'] ??= [];

        List<dynamic> devicesList = List<dynamic>.from(mp3Data['Devices'] as List<dynamic>? ?? []);
        _debugInfoOnError += "Devices list from MP3 data: $devicesList\n";
        bool currentDeviceFound = devicesList.any((d) => d is Map && d.containsKey(deviceNameVar));
        _debugInfoOnError += "Current device '$deviceNameVar' found in list: $currentDeviceFound\n";

        if (!currentDeviceFound) {
          _debugInfoOnError += "Current device '$deviceNameVar' not in MP3's devices list. Adding it with default position.\n";
          devicesList.add({deviceNameVar: defaultPosition});
          mp3Data['Devices'] = devicesList;
          modified = true;
        }
        workingBasketContent[currMP3] = mp3Data;
      }

      if (modified) {
        _debugInfoOnError += "Basket was modified. Attempting to update Pantry with newBasket...\n";
        await locPan!.newBasket(basketVar, workingBasketContent);
        _debugInfoOnError += "Pantry newBasket call completed.\n";
        basketContent = workingBasketContent;
      }

      final mp3DataForParsing = basketContent[currMP3] as Map<String, dynamic>?;
      _debugInfoOnError += "Final MP3 data for parsing: $mp3DataForParsing\n";

      if (mp3DataForParsing != null && mp3DataForParsing['Devices'] is List) {
        _debugInfoOnError += "Parsing devices from MP3 data...\n";
        List<DevicePosition> parsed = _parseDevicesFromData(mp3DataForParsing['Devices']);
        _debugInfoOnError += "Parsed devices: ${parsed.map((p) => '${p.deviceName}: C=${p.chapterIndex}, T=${p.timestamp}').toList()}\n";
        return parsed;
      }
      _debugInfoOnError += "No 'Devices' list found in MP3 data or MP3 data is null. Returning empty list.\n";
      return [];
    } catch (e, s) {
      _debugInfoOnError += "CRITICAL ERROR during Pantry operation or data processing:\n";
      _debugInfoOnError += "Error Type: ${e.runtimeType}\n";
      _debugInfoOnError += "Error: $e\n";
      _debugInfoOnError += "Stack Trace:\n$s\n";
      print("Error in _getListOfDevicesAndPositionsWithCreation (DeviceSelect): $e\n$s");
      return Future.error(e);
    }
  }

  void _onDeviceSelected(DevicePosition position) {
    currentChapterIndex = position.chapterIndex;
    currentTimestamp = position.timestamp;

    print("DeviceSelect: Set start position to Chapter ${position.chapterIndex + 1} @ ${position.timestamp}s.");

    // When selecting a position, we still want to update *our own* device's timestamp to match.
    _updatePantryTimestampGlobal(position.chapterIndex, position.timestamp).then((_) {
      print("DeviceSelect: Pantry updated for current device '$deviceNameVar' to match selected position.");
      if (mounted) Navigator.pushReplacementNamed(context, '/main');
    }).catchError((e) {
      print("DeviceSelect: Error updating Pantry for current device '$deviceNameVar': $e. Navigating anyway.");
      if (mounted) Navigator.pushReplacementNamed(context, '/main');
    });
  }

  String _formatDuration(double totalSeconds) {
    final duration = Duration(seconds: totalSeconds.round());
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}h ${twoDigitMinutes}m ${twoDigitSeconds}s";
    }
    return "${twoDigitMinutes}m ${twoDigitSeconds}s";
  }

  // --- NEW ---
  // Method to handle the deletion of a device position from Pantry.
  Future<void> _deleteDevicePosition(String deviceNameToDelete) async {
    if (locPan == null || currMP3.isEmpty || basketVar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Pantry client not configured.")),
      );
      return;
    }

    try {
      Map<String, dynamic>? basketContent = await locPan!.getBasket(basketVar);
      if (basketContent == null || !basketContent.containsKey(currMP3)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Book data not found in Pantry.")),
        );
        return;
      }

      Map<String, dynamic> mp3Data = Map<String, dynamic>.from(basketContent[currMP3]);
      List<dynamic> devicesList = List<dynamic>.from(mp3Data['Devices'] as List<dynamic>? ?? []);

      devicesList.removeWhere((d) => d is Map && d.containsKey(deviceNameToDelete));

      mp3Data['Devices'] = devicesList;
      basketContent[currMP3] = mp3Data;

      await locPan!.newBasket(basketVar, basketContent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Device position '$deviceNameToDelete' deleted.")),
        );
        // Refresh the list after deletion
        _initializeAndFetchData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete position: $e")),
        );
      }
      print("Error deleting device position: $e");
    }
  }

  // --- NEW ---
  // Shows a confirmation dialog before deleting a device position.
  void _showDeleteDeviceConfirmationDialog(DevicePosition position) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Position?"),
          content: Text("Are you sure you want to delete the saved position for '${position.deviceName}'? This action cannot be undone."),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Delete"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _deleteDevicePosition(position.deviceName);
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final String bookTitleAbbrev = currentBook?.title ?? "Audiobook";

    return Scaffold(
      appBar: AppBar(
        title: Text("Positions for '$bookTitleAbbrev'", overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.lightBlueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeAndFetchData,
            tooltip: "Refresh List",
          ),
          IconButton(
            icon: const Icon(Icons.library_books),
            onPressed: () { if (mounted) Navigator.pushReplacementNamed(context, '/ABSelect'); },
            tooltip: "Back to book selection",
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () { if (mounted) Navigator.pushReplacementNamed(context, '/settings'); },
            tooltip: "Go to settings",
          )
        ],
      ),
      body: FutureBuilder<List<DevicePosition>?>(
        future: _devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            String errorMsg = snapshot.error.toString();
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Error Loading Device Data:",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Original error: $errorMsg",
                        style: TextStyle(color: Colors.red.shade300, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Debug Information:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.left,
                      ),
                      SizedBox(height: 5),
                      Container(
                        padding: EdgeInsets.all(8),
                        color: Colors.grey[200],
                        child: Text(
                          _debugInfoOnError.isNotEmpty ? _debugInfoOnError : "No additional debug info captured.",
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text("Try Again"),
                        onPressed: _initializeAndFetchData,
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.settings),
                        label: Text("Check Settings"),
                        onPressed: () {
                          if (mounted) Navigator.pushReplacementNamed(context, '/settings');
                        },
                      )
                    ],
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Could not load device data. No specific error, or data is null.", textAlign: TextAlign.center),
                        SizedBox(height: 10),
                        Text(
                          "Debug Information:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.left,
                        ),
                        SizedBox(height: 5),
                        Container(
                          padding: EdgeInsets.all(8),
                          color: Colors.grey[200],
                          child: Text(
                            _debugInfoOnError.isNotEmpty ? _debugInfoOnError : "No debug info captured.",
                            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                            textAlign: TextAlign.left,
                          ),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: Icon(Icons.refresh),
                          label: Text("Try Again"),
                          onPressed: _initializeAndFetchData,
                        ),
                      ]
                  )
              ),
            );
          }

          final devices = snapshot.data!;

          if (devices.isEmpty && deviceNameVar.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "No saved positions found for '$bookTitleAbbrev'.\n"
                          "If this is the first time for this book/device, this is normal.\n"
                          "A new position for this device ('$deviceNameVar') at the beginning (0s) should have been created in Pantry.\n"
                          "Tap 'Refresh' to see if it appears, or proceed by selecting this device (it might not be listed yet until refresh after creation).",
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: Icon(Icons.refresh),
                      label: Text("Refresh List"),
                      onPressed: _initializeAndFetchData,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Debug Information (for empty list scenario):",
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.left,
                    ),
                    SizedBox(height: 5),
                    Container(
                      padding: EdgeInsets.all(8),
                      color: Colors.grey[200],
                      child: Text(
                        _debugInfoOnError.isNotEmpty ? _debugInfoOnError : "No debug info captured.",
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final position = devices[index];
              final String name = position.deviceName;

              String formattedSubtitle;
              if (currentBook?.isChaptered ?? false) {
                formattedSubtitle = "Chapter ${position.chapterIndex + 1} at ${_formatDuration(position.timestamp)}";
              } else {
                formattedSubtitle = "Last position: ${_formatDuration(position.timestamp)}";
              }

              bool isCurrentDevice = (name == deviceNameVar);

              return GestureDetector(
                onLongPress: () {
                  _showDeleteDeviceConfirmationDialog(position);
                },
                child: ListTile(
                  leading: Icon(isCurrentDevice ? Icons.phonelink_ring : Icons.devices_other, color: Colors.lightBlueAccent),
                  title: Text(name, style: TextStyle(fontWeight: isCurrentDevice ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(formattedSubtitle),
                  onTap: () => _onDeviceSelected(position),
                  tileColor: isCurrentDevice ? Colors.lightBlue[50] : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =========================================================================
// ==================== ALL CHANGES ARE IN THIS CLASS ======================
// =========================================================================
class Main extends StatefulWidget {
  const Main({Key? key}) : super(key: key);

  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _audiobooksPath;
  Source? _currentSource;

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoadingFile = true;

  List<String> _notes = [];
  late TextEditingController _noteInputController;
  late TextEditingController _timeInputController;

  // --- Car Mode and Voice Note State ---
  bool _isCarMode = false;
  late SpeechToText _speech;
  bool _isVoiceNoteSupported = false;

  // NEW: State variables to manage the voice note *session*
  bool _isVoiceSessionActive = false; // Is the user currently in a note-taking session?
  String _sessionWords = '';          // Holds the complete transcript for the current session.
  String _currentWords = '';          // Holds the words from the current listening *cycle*.

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<void>? _playerCompleteSubscription;

  @override
  void initState() {
    super.initState();
    _noteInputController = TextEditingController();
    _timeInputController = TextEditingController();

    if (Platform.isAndroid || Platform.isIOS) {
      _isVoiceNoteSupported = true;
      _speech = SpeechToText();
      _initSpeech(); // Initialize the speech-to-text listener logic
    }

    _initAudioAndLoadData();

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;

      // NEW: Auto-play next chapter if available
      if (currentBook?.isChaptered ?? false) {
        if (currentChapterIndex < currentBook!.chapters.length - 1) {
          print("Chapter finished. Advancing to next chapter.");
          _nextChapter(play: true); // Automatically play the next one
        } else {
          print("Final chapter finished.");
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.pause();
          setState(() {
            _currentPosition = Duration.zero;
          });
        }
      } else {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
        setState(() {
          _currentPosition = Duration.zero;
        });
      }
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((Duration duration) {
      if (!mounted) return;
      setState(() {
        _totalDuration = duration;
      });
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((Duration position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
    });
  }

  // --- NEW AND REFACTORED VOICE NOTE METHODS ---

  /// Initializes the speech-to-text plugin and sets up the listeners.
  /// This only needs to run once.
  void _initSpeech() async {
    await _speech.initialize(
      onError: _errorListener,
      onStatus: _statusListener,
    );
  }

  /// Toggles the voice note session on or off.
  /// This is the main entry point called by the UI.
  void _toggleVoiceNoteSession() async {
    if (!_isVoiceNoteSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Voice notes are not supported on this device.")),
      );
      return;
    }

    if (_isVoiceSessionActive) {
      // If a session is active, stop it.
      await _stopListeningCycle();
    } else {
      // If no session is active, start one.
      if (_isPlaying) await _audioPlayer.pause();
      setState(() {
        _isVoiceSessionActive = true;
        _sessionWords = ''; // Clear previous session's transcript
        _currentWords = '';
      });
      _startListeningCycle();
    }
  }

  /// Starts a single listening cycle.
  void _startListeningCycle() async {
    // A small delay helps ensure the previous cycle has fully stopped.
    await Future.delayed(const Duration(milliseconds: 50));
    await _speech.listen(
      onResult: _onSpeechResult,
      // The timeout before the `done` status is sent.
      // With the restart logic, this is how long it waits for a pause.
      pauseFor: const Duration(seconds: 5),
      // This is less critical with pauseFor, but good to have a safety net.
      listenFor: const Duration(minutes: 5),
      // Use partial results for a more responsive UI
      partialResults: true,
      // Use options object for modern API
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
      ),
    );
  }

  /// Manually stops the listening cycle and ends the session.
  Future<void> _stopListeningCycle() async {
    // Set the flag to false *before* stopping.
    // This tells the statusListener not to restart the cycle.
    setState(() {
      _isVoiceSessionActive = false;
    });
    await _speech.stop();
  }

  /// Callback for when the listening status changes (e.g., 'listening', 'done').
  void _statusListener(String status) async {
    print("Speech status: $status");
    if (status == 'done') {
      // When a listening cycle ends, append its final words to the session transcript.
      setState(() {
        if (_currentWords.isNotEmpty) {
          _sessionWords = _sessionWords.isEmpty ? _currentWords : '$_sessionWords $_currentWords';
        }
        _currentWords = ''; // Clear the current cycle's words
      });

      if (_isVoiceSessionActive) {
        // If the session is still meant to be active, immediately start the next cycle.
        print("Restarting listening cycle...");
        _startListeningCycle();
      } else {
        // If the session has been stopped by the user, this is the end.
        // Save the complete note and resume playback.
        print("Voice session ended. Saving note.");
        if (_sessionWords.isNotEmpty) {
          await _saveNote(_sessionWords);
        }
        await _playAudio();
      }
    }
  }

  /// Callback for speech recognition errors.
  void _errorListener(e) {
    print("Speech error: $e");
    // If an error occurs, ensure the session is properly terminated.
    if (_isVoiceSessionActive) {
      _stopListeningCycle();
    }
  }

  /// Callback that updates the UI with recognized words in real-time.
  void _onSpeechResult(result) {
    setState(() {
      _currentWords = result.recognizedWords;
    });
  }

  // --- END OF NEW AND REFACTORED VOICE NOTE METHODS ---

  Future<void> _initAudioAndLoadData() async {
    if (!mounted) return;
    setState(() { _isLoadingFile = true; });
    _audiobooksPath = await getAudiobooksDirectoryPath(context);

    if (_audiobooksPath == null || currentBook == null || currMP3.isEmpty) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Error: No book selected. Try selecting again.")),
            );
            Navigator.pushReplacementNamed(context, '/ABSelect');
          }
        });
      }
      if (mounted) setState(() { _isLoadingFile = false; });
      return;
    }

    // NEW: Load the specific chapter file.
    await _loadChapter(currentChapterIndex, seekToTimestamp: currentTimestamp, autoPlay: false);
    await _loadNotesFromPantry();
  }

  // NEW: Helper function to load a specific chapter.
  Future<void> _loadChapter(int chapterIndex, {double? seekToTimestamp, bool autoPlay = true}) async {
    if (currentBook == null || chapterIndex < 0 || chapterIndex >= currentBook!.chapters.length) {
      print("Error: Invalid chapter index $chapterIndex");
      return;
    }

    if (mounted) setState(() => _isLoadingFile = true);

    await _audioPlayer.stop(); // Stop any current playback before changing source.

    final file = currentBook!.chapters[chapterIndex];
    if (!await file.exists()) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: Chapter file not found: ${p.basename(file.path)}")),
            );
            Navigator.pushReplacementNamed(context, '/ABSelect');
          }
        });
      }
      if (mounted) setState(() => _isLoadingFile = false);
      return;
    }

    try {
      _currentSource = DeviceFileSource(file.path);
      await _audioPlayer.setSource(_currentSource!);
      currentChapterIndex = chapterIndex; // Update the global index

      // Wait a moment for the player to process the new source before getting duration/seeking.
      await Future.delayed(const Duration(milliseconds: 200));

      Duration? reportedDuration = await _audioPlayer.getDuration();
      if (reportedDuration != null && mounted) {
        setState(() {
          _totalDuration = reportedDuration;
        });
      }

      final seekToPosition = Duration(seconds: (seekToTimestamp ?? 0.0).round());
      if (_totalDuration > Duration.zero && seekToPosition <= _totalDuration) {
        await _audioPlayer.seek(seekToPosition);
      }

      if (autoPlay) {
        await _playAudio();
      }

    } catch (e, s) {
      print("Error in _loadChapter: $e\n$s");
    } finally {
      if (mounted) setState(() => _isLoadingFile = false);
    }
  }

  Future<void> _loadNotesFromPantry() async {
    if (locPan == null || currMP3.isEmpty || basketVar.isEmpty) return;
    try {
      final basketContent = await locPan!.getBasket(basketVar);
      if (basketContent != null && basketContent.containsKey(currMP3)) {
        final mp3Data = basketContent[currMP3] as Map<String, dynamic>?;
        if (mp3Data != null && mp3Data['Notes'] is List) {
          if (mounted) {
            setState(() {
              _notes = List<String>.from(mp3Data['Notes']);
            });
          }
        }
      }
    } catch (e) {
      print("Error loading notes from Pantry in Main: $e");
    }
  }

  String _formatDuration(Duration d, {bool forceHours = false}) {
    d = d < Duration.zero ? Duration.zero : d;
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0 || forceHours) {
      return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  Duration? _parseTimeInput(String input) {
    input = input.replaceAll('/', ':').trim();
    final partsStr = input.split(':');

    if (partsStr.isEmpty || partsStr.length > 3) return null;

    List<int> parts = [];
    for (String pStr in partsStr) {
      int? val = int.tryParse(pStr);
      if (val == null) return null;
      parts.add(val);
    }

    int h = 0, m = 0, s = 0;
    if (parts.length == 3) {
      h = parts[0]; m = parts[1]; s = parts[2];
    } else if (parts.length == 2) {
      m = parts[0]; s = parts[1];
    } else if (parts.length == 1) {
      s = parts[0];
    } else {
      return null;
    }
    if (h < 0 || m < 0 || m >= 60 || s < 0 || s >= 60) return null;
    return Duration(hours: h, minutes: m, seconds: s);
  }

  void _showSeekDialog() {
    _timeInputController.text = _formatDuration(_currentPosition, forceHours: _totalDuration.inHours > 0);

    // NEW: Use a more advanced dialog for chaptered books.
    if (currentBook?.isChaptered ?? false) {
      _showChapterSeekDialog();
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Seek to Time"),
          content: TextField(
            controller: _timeInputController,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(hintText: "HH:MM:SS or MM:SS or SS"),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Seek"),
              onPressed: () {
                final duration = _parseTimeInput(_timeInputController.text);
                if (duration != null) {
                  if (duration <= _totalDuration && duration >= Duration.zero) {
                    _audioPlayer.seek(duration);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Time is out of bounds.")),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Invalid time format.")),
                  );
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // NEW: Dialog for seeking to a specific chapter and time.
  void _showChapterSeekDialog() {
    int? selectedChapter = currentChapterIndex;
    _timeInputController.text = "00:00";

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text("Seek to Chapter and Time"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedChapter,
                      // --- FIX 1: Truncate long chapter names ---
                      items: List.generate(currentBook!.chapters.length, (index) {
                        return DropdownMenuItem(
                          value: index,
                          // Wrap the Text widget in a Flexible to allow it to truncate.
                          child: Text(
                            "Chapter ${index + 1}: ${p.basenameWithoutExtension(currentBook!.chapters[index].path)}",
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedChapter = value;
                          });
                        }
                      },
                      decoration: const InputDecoration(labelText: "Chapter"),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _timeInputController,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(labelText: "Time in chapter", hintText: "HH:MM:SS or MM:SS"),
                      autofocus: true,
                    ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text("Cancel"),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  TextButton(
                    child: const Text("Seek"),
                    onPressed: () {
                      final duration = _parseTimeInput(_timeInputController.text);
                      if (duration != null && selectedChapter != null) {
                        _loadChapter(selectedChapter!, seekToTimestamp: duration.inSeconds.toDouble(), autoPlay: _isPlaying);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Invalid chapter or time format.")),
                        );
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        });
  }

  void _addNote() async {
    final noteText = _noteInputController.text.trim();
    if (noteText.isNotEmpty) {
      await _saveNote(noteText);
      _noteInputController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _saveNote(String noteText) async {
    final trimmedText = noteText.trim();
    if (trimmedText.isNotEmpty) {
      final timeStr = _formatDuration(_currentPosition, forceHours: _totalDuration.inHours > 0);

      // NEW: Prepend chapter info to note if applicable.
      final String prefix;
      if (currentBook?.isChaptered ?? false) {
        prefix = "Ch ${currentChapterIndex + 1} @ $timeStr-$deviceNameVar:";
      } else {
        prefix = "$timeStr-$deviceNameVar:";
      }

      final newNote = "$prefix $trimmedText";
      if (!mounted) return;
      setState(() {
        _notes.insert(0, newNote);
      });
      await _updatePantryNotesGlobal(List<String>.from(_notes));
    }
  }

  Future<void> _handlePlayPause() async {
    if (_audioPlayer.state == PlayerState.playing) {
      await _audioPlayer.pause();
      await _updatePantryTimestampGlobal(currentChapterIndex, _currentPosition.inSeconds.toDouble());
    } else {
      await _playAudio();
    }
  }

  Future<void> _playAudio() async {
    if (_currentSource != null) {
      if (_audioPlayer.state == PlayerState.completed) {
        await _audioPlayer.seek(Duration.zero);
      }
      await _audioPlayer.play(_currentSource!);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Audio source error. Reloading...")),
        );
        await _initAudioAndLoadData();
        if (_currentSource != null && !_isLoadingFile) {
          await _audioPlayer.play(_currentSource!);
        }
      }
    }
  }

  void _seekRelative(Duration offset) {
    var newPos = _currentPosition + offset;
    if (newPos < Duration.zero) newPos = Duration.zero;
    if (_totalDuration > Duration.zero && newPos > _totalDuration) newPos = _totalDuration;
    _audioPlayer.seek(newPos);
  }

  // NEW: Methods for chapter navigation
  void _nextChapter({bool play = true}) {
    if (currentBook != null && currentChapterIndex < currentBook!.chapters.length - 1) {
      _loadChapter(currentChapterIndex + 1, seekToTimestamp: 0.0, autoPlay: play);
      _updatePantryTimestampGlobal(currentChapterIndex + 1, 0.0);
    }
  }

  void _previousChapter({bool play = true}) {
    if (currentBook != null && currentChapterIndex > 0) {
      _loadChapter(currentChapterIndex - 1, seekToTimestamp: 0.0, autoPlay: play);
      _updatePantryTimestampGlobal(currentChapterIndex - 1, 0.0);
    }
  }

  Future<void> _pauseAndSaveTimestamp() async {
    if (_audioPlayer.state == PlayerState.playing) {
      await _audioPlayer.pause();
    }
    await _updatePantryTimestampGlobal(currentChapterIndex, _currentPosition.inSeconds.toDouble());
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _noteInputController.dispose();
    _timeInputController.dispose();
    if (_isVoiceNoteSupported) {
      _speech.cancel();
    }
    super.dispose();
  }

  // --- NEW: NOTE EDIT/DELETE LOGIC ---

  // Shows the main options dialog for a note.
  void _showNoteOptionsDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Note Options"),
        content: Text(_notes[index]),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
            onPressed: () {
              Navigator.of(context).pop(); // Close options
              _showDeleteNoteConfirmationDialog(index);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlueAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("Edit"),
            onPressed: () {
              Navigator.of(context).pop(); // Close options
              _showEditNoteDialog(index);
            },
          ),
        ],
      ),
    );
  }

  // Shows a confirmation before deleting a note.
  void _showDeleteNoteConfirmationDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Note?"),
        content: const Text("Are you sure you want to permanently delete this note?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
            onPressed: () {
              Navigator.of(context).pop(); // Close confirmation
              _deleteNoteAtIndex(index);
            },
          ),
        ],
      ),
    );
  }

  // Handles the actual deletion of a note.
  Future<void> _deleteNoteAtIndex(int index) async {
    if (!mounted) return;
    setState(() {
      _notes.removeAt(index);
    });
    await _updatePantryNotesGlobal(List<String>.from(_notes));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Note deleted.")),
    );
  }

  // Shows a dialog to edit the content of a note.
  void _showEditNoteDialog(int index) {
    final String fullNote = _notes[index];
    final separator = ": ";
    final separatorIndex = fullNote.indexOf(separator);

    String prefix = "";
    String content = fullNote;

    if (separatorIndex != -1) {
      prefix = fullNote.substring(0, separatorIndex + separator.length);
      content = fullNote.substring(separatorIndex + separator.length);
    }

    final editController = TextEditingController(text: content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Note"),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 5,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: "Note content",
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlueAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("Save Changes"),
            onPressed: () {
              Navigator.of(context).pop();
              _updateNoteAtIndex(index, prefix, editController.text);
            },
          ),
        ],
      ),
    );
  }

  // Handles updating the note after editing.
  Future<void> _updateNoteAtIndex(int index, String prefix, String newContent) async {
    final updatedNote = "$prefix${newContent.trim()}";
    if (!mounted) return;
    setState(() {
      _notes[index] = updatedNote;
    });
    await _updatePantryNotesGlobal(List<String>.from(_notes));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Note updated.")),
    );
  }

  // --- END OF NOTE EDIT/DELETE LOGIC ---


  Widget _buildRegularModeUI() {
    return Column(
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text("Notes", style: Theme.of(context).textTheme.titleLarge),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _noteInputController,
                decoration: const InputDecoration(
                  hintText: "Add a note...",
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _isLoadingFile ? null : (_) => _addNote(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_comment, color: Colors.lightBlueAccent),
              onPressed: _isLoadingFile ? null : _addNote,
              tooltip: "Add Note",
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _notes.isEmpty
              ? const Center(child: Text("No notes yet for this audiobook."))
              : ListView.separated(
            itemCount: _notes.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onLongPress: () => _showNoteOptionsDialog(index),
                child: ListTile(
                  dense: true,
                  title: Text(_notes[index]),
                ),
              );
            },
            separatorBuilder: (context, index) => const Divider(height:1),
          ),
        ),
      ],
    );
  }

  Widget _buildCarModeUI() {
    // Combine the session words and current cycle words for a complete, real-time view.
    final displayedText = '$_sessionWords $_currentWords'.trim();

    return Expanded(
      child: GestureDetector(
        onTap: _isLoadingFile ? null : _toggleVoiceNoteSession,
        child: Container(
          margin: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            color: _isVoiceSessionActive ? Colors.lightBlue[100] : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isVoiceSessionActive ? Icons.mic : Icons.mic_none,
                  size: 80,
                  color: Colors.black54,
                ),
                const SizedBox(height: 20),
                Text(
                  _isVoiceSessionActive ? "Listening..." : "Tap to Record a Note",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black54),
                ),
                if (displayedText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      '"$displayedText"',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // NEW: This widget contains the chapter navigation controls.
  Widget _buildChapterControls() {
    bool isChaptered = currentBook?.isChaptered ?? false;
    // We use a SizedBox to preserve the vertical space and keep the main controls
    // in the same position, fulfilling the muscle memory requirement.
    const placeholder = SizedBox(height: 58.0);

    if (!isChaptered) return placeholder;

    return Container(
      height: 58.0, // Same height as the placeholder
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous),
            iconSize: 32.0,
            onPressed: (_isLoadingFile || currentChapterIndex == 0) ? null : () => _previousChapter(play: _isPlaying),
            tooltip: "Previous Chapter",
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Chapter ${currentChapterIndex + 1} / ${currentBook?.chapters.length ?? '?'}",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  p.basenameWithoutExtension(currentBook!.chapters[currentChapterIndex].path),
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            iconSize: 32.0,
            onPressed: (_isLoadingFile || currentBook == null || currentChapterIndex >= currentBook!.chapters.length - 1) ? null : () => _nextChapter(play: _isPlaying),
            tooltip: "Next Chapter",
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String bookTitle = currentBook?.title ?? "Audio Player";

    return Scaffold(
      appBar: AppBar(
        title: Text(bookTitle, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.lightBlueAccent,
        foregroundColor: Colors.white,
        actions: [
          if (_isVoiceNoteSupported)
            IconButton(
              icon: Icon(_isCarMode ? Icons.notes : Icons.directions_car),
              onPressed: () => setState(() => _isCarMode = !_isCarMode),
              tooltip: _isCarMode ? "Exit Car Mode" : "Enter Car Mode",
            ),
          IconButton(
            icon: const Icon(Icons.input),
            onPressed: _isLoadingFile ? null : _showSeekDialog,
            tooltip: "Seek to specific time",
          ),
          IconButton(
            icon: const Icon(Icons.devices_other),
            onPressed: () async {
              await _pauseAndSaveTimestamp();
              if (mounted) Navigator.pushReplacementNamed(context, '/DeviceSelect');
            },
            tooltip: "Change saved position",
          ),
          IconButton(
            icon: const Icon(Icons.library_books),
            onPressed: () async {
              await _pauseAndSaveTimestamp();
              if (mounted) Navigator.pushReplacementNamed(context, '/ABSelect');
            },
            tooltip: "Select different audiobook",
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await _pauseAndSaveTimestamp();
              if (mounted) Navigator.pushReplacementNamed(context, '/settings');
            },
            tooltip: "Go to settings",
          )
        ],
      ),
      body: _isLoadingFile
          ? const Center(child: CircularProgressIndicator())
          : currMP3.isEmpty
          ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("No audiobook selected or error loading.", textAlign: TextAlign.center),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/ABSelect'),
                child: const Text("Select Audiobook"),
              )
            ],
          )
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(_formatDuration(_currentPosition, forceHours: _totalDuration.inHours > 0), style: Theme.of(context).textTheme.titleMedium),
            Slider(
              value: (_totalDuration == Duration.zero) ? 0.0 :
              _currentPosition.inMilliseconds.toDouble().clamp(0.0, _totalDuration.inMilliseconds.toDouble()),
              min: 0.0,
              max: (_totalDuration == Duration.zero) ? 1.0 : _totalDuration.inMilliseconds.toDouble(),
              onChanged: (value) {
                if (_totalDuration > Duration.zero) {
                  _audioPlayer.seek(Duration(milliseconds: value.round()));
                }
              },
              activeColor: Colors.lightBlueAccent,
            ),
            Text(_formatDuration(_totalDuration, forceHours: _totalDuration.inHours > 0), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),

            _buildChapterControls(), // NEW: Chapter controls are inserted here.

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_30),
                  iconSize: 48.0,
                  onPressed: _isLoadingFile ? null : () => _seekRelative(const Duration(seconds: -30)),
                  tooltip: "Rewind 30 seconds",
                ),
                IconButton(
                  icon: _isLoadingFile
                      ? const SizedBox(width: 64.0, height: 64.0, child: CircularProgressIndicator())
                      : Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  iconSize: 64.0,
                  color: Colors.lightBlueAccent,
                  onPressed: _isLoadingFile ? null : _handlePlayPause,
                  tooltip: _isPlaying ? "Pause" : "Play",
                ),
                IconButton(
                  icon: const Icon(Icons.forward_30),
                  iconSize: 48.0,
                  onPressed: _isLoadingFile ? null : () => _seekRelative(const Duration(seconds: 30)),
                  tooltip: "Forward 30 seconds",
                ),
              ],
            ),
            _isCarMode ? _buildCarModeUI() : Expanded(child: _buildRegularModeUI()),
          ],
        ),
      ),
    );
  }
}