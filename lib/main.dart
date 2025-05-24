//Linux dependencies for audioplayers (typically GStreamer based):
//sudo apt install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev (example, check audioplayers docs for specifics)
// sudo add-apt-repository ppa:gstreamer-developers/ppa
// sudo apt-get update
// sudo apt-get install gstreamer1.0*


import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; // For Directory and File
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p; // For path manipulation
import 'package:pantry/pantry.dart'; // Assuming this is your Pantry client library
import 'dart:async'; // For Future.value and StreamSubscription

// import 'package:just_audio/just_audio.dart'; // REMOVED
import 'package:audioplayers/audioplayers.dart'; // ADDED
// The example also imports audio_cache.dart, let's keep it for consistency, though not directly used in Main for file playback.
import 'package:device_info_plus/device_info_plus.dart';


// Global variables (as provided)
String keyVar = '';
String basketVar = '';
String deviceNameVar = ''; // Name of the CURRENT device
String currMP3 = "";
double currTimestamp = -1; // In seconds
Pantry? locPan; // Your Pantry client instance

// --- Global Pantry Helper Functions ---
Future<void> _updatePantryTimestampGlobal(double positionInSeconds) async {
  if (locPan == null || currMP3.isEmpty || deviceNameVar.isEmpty || basketVar.isEmpty) {
    print("Pantry update timestamp: Missing required global variables. locPan: $locPan, currMP3: $currMP3, deviceNameVar: $deviceNameVar, basketVar: $basketVar");
    return;
  }
  try {
    var basketData = await locPan!.getBasket(basketVar);
    if (basketData == null) {
      basketData = {};
      print("Warning: Basket '$basketVar' was null, initializing as empty for timestamp update.");
    }

    if (!basketData.containsKey(currMP3)) {
      basketData[currMP3] = {'Notes': [], 'Devices': []};
      print("Info: MP3 entry '$currMP3' created for timestamp update.");
    }
    Map<String, dynamic> mp3Entry = Map<String, dynamic>.from(basketData[currMP3]);
    if (mp3Entry['Devices'] == null || !(mp3Entry['Devices'] is List)) {
      mp3Entry['Devices'] = [];
      print("Info: 'Devices' list created for '$currMP3' during timestamp update.");
    }
    if (mp3Entry['Notes'] == null || !(mp3Entry['Notes'] is List)) { // Preserve Notes
      mp3Entry['Notes'] = [];
    }

    List<dynamic> devicesList = List<dynamic>.from(mp3Entry['Devices']);

    int deviceIndex = devicesList.indexWhere((d) => d is Map && d.containsKey(deviceNameVar));
    if (deviceIndex != -1) {
      (devicesList[deviceIndex] as Map)[deviceNameVar] = positionInSeconds;
    } else {
      devicesList.add({deviceNameVar: positionInSeconds});
    }
    mp3Entry['Devices'] = devicesList;
    basketData[currMP3] = mp3Entry;

    var pantryResult = await locPan!.newBasket(basketVar, basketData);
    print("Pantry timestamp updated for $deviceNameVar in $currMP3 to $positionInSeconds s. Result: $pantryResult");
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
    if (basketData == null) {
      basketData = {};
      print("Warning: Basket '$basketVar' was null, initializing as empty for notes update.");
    }

    if (!basketData.containsKey(currMP3)) {
      basketData[currMP3] = {'Notes': [], 'Devices': []};
      print("Info: MP3 entry '$currMP3' created for notes update.");
    }
    Map<String, dynamic> mp3Entry = Map<String, dynamic>.from(basketData[currMP3]);
    if (mp3Entry['Devices'] == null || !(mp3Entry['Devices'] is List)) { // Preserve Devices
      mp3Entry['Devices'] = [];
    }

    mp3Entry['Notes'] = notes;
    basketData[currMP3] = mp3Entry;

    var pantryResult = await locPan!.newBasket(basketVar, basketData);
    print("Pantry notes updated for $currMP3. Result: $pantryResult");
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

// In your main file, ensure you have access to a BuildContext for SnackBar.
// If getAudiobooksDirectoryPath is called from initState where context might not be fully ready for SnackBars,
// consider passing the context or using a post-frame callback. For simplicity, let's assume
// it's called from a place where showing a SnackBar is feasible (e.g., a button press or after UI is built).
// If not, we'll use print and you'll have to rely on logs if you connect via ADB later.

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

      if (sdkInt < 30) {
        // ... (Legacy permission logic - same as before) ...
        _logDebug("SDK < 30. Requesting legacy Permission.storage.");
        PermissionStatus storageStatus = await Permission.storage.status;
        _logDebug("Initial Permission.storage status: ${storageStatus.name}");
        if (!storageStatus.isGranted) {
          storageStatus = await Permission.storage.request();
          _logDebug("After request, Permission.storage status: ${storageStatus.name}");
        }
        hasSufficientPermissions = storageStatus == PermissionStatus.granted;
        if (!hasSufficientPermissions) {
          _logDebug("Legacy storage permissions were not granted for SDK < 30.");
        }
      } else { // SDK >= 30
        // ... (MANAGE_EXTERNAL_STORAGE logic - same as before) ...
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
              PermissionStatus statusAfterRequest = await Permission.manageExternalStorage.request();
              _logDebug("After attempting to open settings for Permission.manageExternalStorage, status: ${statusAfterRequest.name}");
              // Re-check status, as request() might just open settings
              hasSufficientPermissions = await Permission.manageExternalStorage.status == PermissionStatus.granted;
              if (!hasSufficientPermissions) {
                _logDebug("MANAGE_EXTERNAL_STORAGE was still not granted after settings trip.");
                _showDebugPopup("Permission Denied", "MANAGE_EXTERNAL_STORAGE (All files access) was not granted. This is required. Please grant it manually in App Settings for this app, then try again.", isError: true);
              } else {
                _logDebug("MANAGE_EXTERNAL_STORAGE appears to be granted after settings trip.");
              }
            });
            // Ensure hasSufficientPermissions is updated after the async flow
            if (await Permission.manageExternalStorage.status == PermissionStatus.granted) {
              hasSufficientPermissions = true;
            }
          } else {
            _logDebug("Context not available or dialog already showing, cannot show explanatory dialog for MANAGE_EXTERNAL_STORAGE.");
            PermissionStatus statusAfterDirectRequest = await Permission.manageExternalStorage.request();
            hasSufficientPermissions = statusAfterDirectRequest == PermissionStatus.granted;
            if (!hasSufficientPermissions) _logDebug("Direct request for MANAGE_EXTERNAL_STORAGE failed.");
          }
        } else {
          _logDebug("MANAGE_EXTERNAL_STORAGE was already granted.");
          hasSufficientPermissions = true;
        }
      }

      if (hasSufficientPermissions) {
        _logDebug("Sufficient storage permissions appear granted. Attempting to find public shared storage root...");

        String? publicRootPath;
        List<Directory>? allExternalDirs = await getExternalStorageDirectories(type: null);

        if (allExternalDirs != null && allExternalDirs.isNotEmpty) {
          _logDebug("Available external directories from getExternalStorageDirectories(type: null):");
          for (var dir in allExternalDirs) {
            _logDebug("- ${dir.path}");
            // Heuristic: The public root is less likely to contain "/Android/data/" in its path.
            // This is not foolproof but often works.
            if (!dir.path.contains("/Android/data/")) {
              publicRootPath = dir.path;
              _logDebug("Selected candidate for public root: $publicRootPath (does not contain '/Android/data/')");
              break; // Take the first one that matches this heuristic
            }
          }
          if (publicRootPath == null) {
            // If all paths contained /Android/data/, maybe the first one is the best guess anyway,
            // or path_provider is behaving unexpectedly for your device/SDK.
            // Let's default to the first one if heuristic fails, but log a warning.
            publicRootPath = allExternalDirs.first.path;
            _logDebug("Heuristic for public root failed (all paths contained '/Android/data/'). Defaulting to first path: $publicRootPath. This might be app-scoped.");
            // If this default publicRootPath *is* app-scoped, then the user's /storage/emulated/X/Audiobooks will not be found by joining with it.
            // This is likely the core issue you are facing.

            // **** STRONGER ATTEMPT: Check for known common paths if heuristic fails ****
            // This is more brittle but might work if path_provider is problematic.
            List<String> commonRoots = ["/storage/emulated/11", "/sdcard", "/mnt/sdcard"];
            for (String commonRoot in commonRoots) {
              Directory testDir = Directory(commonRoot);
              if (await testDir.exists()) {
                // Check if we can list contents (basic permission check for the root itself)
                try {
                  await testDir.list(recursive: false, followLinks: false).first; // Try to list one item
                  publicRootPath = commonRoot;
                  _logDebug("Common path check: Found and can access '$commonRoot'. Using this as public root.");
                  break;
                } catch (e) {
                  _logDebug("Common path check: Found '$commonRoot' but cannot list contents: $e");
                }
              } else {
                _logDebug("Common path check: '$commonRoot' does not exist.");
              }
            }
            if (!commonRoots.contains(publicRootPath) && allExternalDirs.first.path.contains("/Android/data")) {
              _logDebug("WARNING: After all checks, derived publicRootPath '$publicRootPath' still looks app-scoped. The custom 'Audiobooks' folder might not be found correctly.");
              // At this point, if publicRootPath is still like /storage/emulated/0/Android/data/..., then p.join(publicRootPath, "Audiobooks") will be wrong.
              // We might need to inform the user that we couldn't find the true public root.
            }
          }
        }


        if (publicRootPath != null) {
          _logDebug("Using determined public root path: $publicRootPath");

          finalPath = p.join(publicRootPath, customFolderName); // e.g., /storage/emulated/0/Audiobooks
          directory = Directory(finalPath);
          _logDebug("Targeting custom path: $finalPath");

          if (!await directory.exists()) {
            _logDebug("ERROR: Target Android directory $finalPath does NOT exist.");
            _showDebugPopup("Folder Not Found",
                "The 'Audiobooks' folder was not found at the expected location: $finalPath\n\n"
                    "Please ensure this folder exists in the root of your phone's internal shared storage (e.g., directly inside 'Internal Storage' or 'sdcard' when viewed from a file manager) and contains your MP3 files.",
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
      // ... (iOS logic - same as before) ...
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
      // ... (Desktop logic - same as before) ...
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
      _logDebug("Path resolved to: $finalPath. Verifying directory object.");
      if (Platform.isAndroid) {
        if (!await directory.exists()) {
          _logDebug("Error: Android directory $finalPath reported as non-existent at final check, though it should have been verified or error reported earlier.");
          _showDebugPopup("Path Error (Android)", "The required Android Audiobooks folder at $finalPath was not found or became inaccessible.", isError: true);
          return null;
        }
      } else {
        if (!await directory.exists()) {
          _logDebug("Error: Directory $finalPath does not exist at final check for non-Android platform.");
          _showDebugPopup("Path Error", "The Audiobooks folder at $finalPath could not be confirmed for non-Android platform.", isError: true);
          return null;
        }
      }
      _logDebug("SUCCESS: Using directory: ${directory.path}");
      return directory.path;
    } else {
      _logDebug("ERROR: Directory or finalPath is null at the end of all logic. This is an internal error in path resolution.");
      _showDebugPopup("Internal Path Error", "Could not resolve a valid directory path due to an internal logic error.\nDebug Log:\n${debugMessages.join('\n')}", isError: true);
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


      if (currMP3.isEmpty || currTimestamp == -1) {
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
                  if (value == null || value.trim().isEmpty) return "Cannot be empty"; // Also trim for validation
                  return null;
                },
              ),
              TextFormField(
                controller: _basketNameController,
                decoration: const InputDecoration(labelText: "Basket Name (created on Pantry website):"),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) return "Cannot be empty"; // Also trim for validation
                  return null;
                },
              ),
              TextFormField(
                controller: _deviceNameController,
                decoration: const InputDecoration(labelText: "Current Device Name (e.g., My Phone):"),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) return "Cannot be empty"; // Also trim for validation
                  return null;
                },
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    // *** MODIFICATION HERE ***
                    final String apiKey = _apiKeyController.text.trim();
                    final String basketName = _basketNameController.text.trim();
                    final String deviceName = _deviceNameController.text.trim();
                    // *** END MODIFICATION ***

                    await setENVVars(
                        apiKey, // Use trimmed value
                        basketName, // Use trimmed value
                        deviceName); // Use trimmed value

                    keyVar = apiKey; // Use trimmed value
                    basketVar = basketName; // Use trimmed value
                    deviceNameVar = deviceName; // Use trimmed value

                    locPan = Pantry(keyVar); // Re-initialize locPan if keyVar changed

                    if (context.mounted) {
                      // Optional: Give user feedback
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
  List<File> _mp3Files = [];
  String? _audiobooksPath;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAudiobooks();
  }

  Future<void> _loadAudiobooks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _mp3Files = [];
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
      final List<File> files = [];
      for (var entity in entities) {
        if (entity is File && p.extension(entity.path).toLowerCase() == '.mp3') {
          files.add(entity);
        }
      }
      files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

      setState(() {
        _mp3Files = files;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading audiobooks: $e");
      setState(() {
        _errorMessage = "Error loading audiobooks: $e";
        _isLoading = false;
      });
    }
  }

  void _selectAudiobook(File file) {
    currMP3 = p.basename(file.path);
    currTimestamp = 0.0;
    print("Selected MP3 for Pantry key: $currMP3. Initial timestamp set to 0.");
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
          else if (_mp3Files.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _audiobooksPath != null
                          ? "No MP3 files found in '$_audiobooksPath'.\nEnsure they end with '.mp3'."
                          : "Could not determine Audiobooks directory.",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _mp3Files.length,
                  itemBuilder: (context, index) {
                    final file = _mp3Files[index];
                    final fileNameWithoutExtension = p.basenameWithoutExtension(file.path);
                    return ListTile(
                      leading: const Icon(Icons.music_note, color: Colors.lightBlueAccent),
                      title: Text(fileNameWithoutExtension),
                      subtitle: Text(p.basename(file.path)),
                      onTap: () => _selectAudiobook(file),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}

class DeviceSelect extends StatefulWidget {
  const DeviceSelect({Key? key}) : super(key: key);

  @override
  _DeviceSelectState createState() => _DeviceSelectState();
}

class _DeviceSelectState extends State<DeviceSelect> {
  Future<List<List<String>>?>? _devicesFuture;
  String _debugInfoOnError = ''; // To store debug messages

  @override
  void initState() {
    super.initState();
    _initializeAndFetchData();
  }

  void _initializeAndFetchData() {
    _debugInfoOnError = ''; // Clear previous debug info
    if (keyVar.isEmpty || locPan == null) { // Assuming keyVar is also a global
      _debugInfoOnError = "Error: Pantry API key or client (locPan) is not initialized.\n"
          "API Key Empty: ${keyVar.isEmpty}\n"
          "locPan is null: ${locPan == null}";
      print(_debugInfoOnError); // For ADB logs
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Pantry client not ready. Go to settings."), duration: Duration(seconds: 3)),
          );
          Navigator.pushReplacementNamed(context, '/settings');
        }
      });
      setState(() {
        _devicesFuture = Future.value(null); // Ensure future completes with error indication
      });
      return;
    }
    setState(() {
      _devicesFuture = _getListOfDevicesAndPositionsWithCreation();
    });
  }

  List<List<String>> _parseDevicesFromData(dynamic devicesListRaw) {
    List<List<String>> parsedList = [];
    if (devicesListRaw is List) {
      for (var deviceEntry in devicesListRaw) {
        if (deviceEntry is Map<String, dynamic> && deviceEntry.isNotEmpty) {
          String deviceName = deviceEntry.keys.first;
          dynamic position = deviceEntry.values.first;
          double positionDouble = 0.0;
          if (position is int) {
            positionDouble = position.toDouble();
          } else if (position is double) {
            positionDouble = position;
          } else if (position is String) {
            positionDouble = double.tryParse(position) ?? 0.0;
          }
          parsedList.add([deviceName, positionDouble.toString()]);
        }
      }
    }
    return parsedList;
  }

  Future<List<List<String>>?> _getListOfDevicesAndPositionsWithCreation() async {
    _debugInfoOnError = "Starting data fetch for DeviceSelect...\n";
    _debugInfoOnError += "locPan available: ${locPan != null}\n";
    _debugInfoOnError += "Basket Variable: '$basketVar'\n";
    _debugInfoOnError += "Current MP3: '$currMP3'\n";
    _debugInfoOnError += "Current Device Name: '$deviceNameVar'\n";

    if (locPan == null) {
      _debugInfoOnError += "Error: locPan is null. Cannot fetch from Pantry.\n";
      print("Error in DeviceSelect: locPan is null.");
      return Future.error(StateError("Pantry client (locPan) is null.")); // Propagate error
    }
    if (currMP3.isEmpty) {
      _debugInfoOnError += "Error: currMP3 is empty. Cannot determine which MP3 data to fetch.\n";
      print("Error in DeviceSelect: currMP3 is empty.");
      if (mounted) Navigator.pushReplacementNamed(context, '/ABSelect');
      return Future.value([]); // Or Future.error
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

      if (!workingBasketContent.containsKey(currMP3)) {
        _debugInfoOnError += "MP3 key '$currMP3' not found in basket. Creating entry with current device '$deviceNameVar'.\n";
        workingBasketContent[currMP3] = {
          "Notes": [],
          "Devices": [ {deviceNameVar: 0.0} ]
        };
        modified = true;
      } else {
        Map<String, dynamic> mp3Data = Map<String, dynamic>.from(workingBasketContent[currMP3]);
        _debugInfoOnError += "MP3 key '$currMP3' found. MP3 Data: $mp3Data\n";
        mp3Data['Notes'] ??= [];

        List<dynamic> devicesList = List<dynamic>.from(mp3Data['Devices'] as List<dynamic>? ?? []);
        _debugInfoOnError += "Devices list from MP3 data: $devicesList\n";
        bool currentDeviceFound = devicesList.any((d) => d is Map && d.containsKey(deviceNameVar));
        _debugInfoOnError += "Current device '$deviceNameVar' found in list: $currentDeviceFound\n";

        if (!currentDeviceFound) {
          _debugInfoOnError += "Current device '$deviceNameVar' not in MP3's devices list. Adding it with 0.0 timestamp.\n";
          devicesList.add({deviceNameVar: 0.0});
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
        List<List<String>> parsed = _parseDevicesFromData(mp3DataForParsing['Devices']);
        _debugInfoOnError += "Parsed devices: $parsed\n";
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
      // Instead of returning null, we throw the error so FutureBuilder can catch it in snapshot.error
      // This allows us to display the _debugInfoOnError in the UI.
      return Future.error(e);
    }
  }

  void _onDeviceSelected(String selectedDeviceName, String positionString) {
    double? position = double.tryParse(positionString);
    position ??= 0.0; // Default to 0.0 if parsing fails

    // 1. CRITICAL: Update the global currTimestamp with the selected device's position.
    currTimestamp = position;
    print("DeviceSelect: currTimestamp updated to $currTimestamp seconds for selected device '$selectedDeviceName'. This will be the starting position in Main.");

    // 2. Update Pantry for the CURRENT device (deviceNameVar) to reflect this new starting position.
    // This means if you select "OldPhone (at 5:00)" while on "NewPhone",
    // "NewPhone" will start at 5:00, AND its timestamp in Pantry will also be set to 5:00.
    // This effectively "syncs" the current device to the selected device's position.
    _updatePantryTimestampGlobal(position).then((_) {
      print("DeviceSelect: Pantry updated for current device '$deviceNameVar' to $position s (from selected device '$selectedDeviceName').");
      if (mounted) Navigator.pushReplacementNamed(context, '/main');
    }).catchError((e) {
      print("DeviceSelect: Error updating Pantry for current device '$deviceNameVar' to $position s: $e. Navigating anyway.");
      if (mounted) Navigator.pushReplacementNamed(context, '/main');
    });
  }

  @override
  Widget build(BuildContext context) {
    final String bookTitleAbbrev = currMP3.isNotEmpty ? p.basenameWithoutExtension(currMP3) : "Audiobook";

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
      body: FutureBuilder<List<List<String>>?>(
        future: _devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Handle errors explicitly and show debug info
          if (snapshot.hasError) {
            String errorMsg = snapshot.error.toString();
            // _debugInfoOnError should already be populated by the catch block in _getListOfDevices...
            // or by initial checks.
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView( // Make it scrollable for long debug info
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
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12), // Monospace for better readability
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
            // This case might be hit if _devicesFuture resolves to null without an error explicitly thrown
            // For example, if initial checks fail before even calling _getListOfDevices...
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
            // This means the future completed successfully with an empty list.
            // Could be that the basket/MP3 entry exists but has no devices,
            // or the logic created an empty list.
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

          // Successfully loaded devices
          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final deviceInfo = devices[index];
              final String name = deviceInfo[0];
              final String positionStr = deviceInfo[1];
              double time = double.tryParse(positionStr) ?? 0.0;

              int hours = (time / 3600).floor();
              int minutes = ((time % 3600) / 60).floor();
              int seconds = (time % 60).round();
              String formattedTime = "";
              if (hours > 0) formattedTime += "${hours}h ";
              formattedTime += "${minutes}m ${seconds}s";

              bool isCurrentDevice = (name == deviceNameVar);

              return ListTile(
                leading: Icon(isCurrentDevice ? Icons.phonelink_ring : Icons.devices_other, color: Colors.lightBlueAccent),
                title: Text(name, style: TextStyle(fontWeight: isCurrentDevice ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text("Last position: $formattedTime"),
                onTap: () => _onDeviceSelected(name, positionStr),
                tileColor: isCurrentDevice ? Colors.lightBlue[50] : null,
              );
            },
          );
        },
      ),
    );
  }
}


class Main extends StatefulWidget {
  const Main({Key? key}) : super(key: key);

  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _audiobooksPath;
  Source? _currentSource; // For audioplayers

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;
  // bool _isBuffering = false; // Removed, _isLoadingFile handles initial load indication
  bool _isLoadingFile = true;

  List<String> _notes = [];
  late TextEditingController _noteInputController;
  late TextEditingController _timeInputController;

  StreamSubscription<PlayerState>? _playerStateSubscription; // audioplayers.PlayerState
  StreamSubscription<Duration>? _durationSubscription; // audioplayers requires Duration, not Duration?
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<void>? _playerCompleteSubscription; // For onPlayerComplete

  @override
  void initState() {
    super.initState();
    _noteInputController = TextEditingController();
    _timeInputController = TextEditingController();
    _initAudioAndLoadData();

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      // Song finished playing
      _audioPlayer.seek(Duration.zero); // Seek to beginning
      _audioPlayer.pause(); // Pause the player
      setState(() {
        _currentPosition = Duration.zero; // Reflect in UI
        // _isPlaying will be set to false by onPlayerStateChanged listener due to pause()
      });
      // Pantry update is handled by _handlePlayPause or explicit calls before navigation
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((Duration duration) {
      if (!mounted) return;
      setState(() {
        _totalDuration = duration; // audioplayers provides non-nullable Duration
      });
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((Duration position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
    });
  }

  Future<void> _initAudioAndLoadData() async {
    if (!mounted) return;
    setState(() { _isLoadingFile = true; });
    _audiobooksPath = await getAudiobooksDirectoryPath(context);

    if (_audiobooksPath == null || currMP3.isEmpty) {
      print("Error: Audiobooks path or current MP3 name is missing in Main.");
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Error: Could not find audiobook path or file. Try selecting again.")),
            );
          }
        });
        Navigator.pushReplacementNamed(context, '/ABSelect');
      }
      if (mounted) setState(() { _isLoadingFile = false; });
      return;
    }

    final filePath = p.join(_audiobooksPath!, currMP3);
    final file = File(filePath);

    if (!await file.exists()) {
      print("Error: Audiobook file does not exist at $filePath");
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: File not found: ${p.basename(currMP3)}. Select again.")),
            );
          }
        });
        Navigator.pushReplacementNamed(context, '/ABSelect');
      }
      if (mounted) setState(() { _isLoadingFile = false; });
      return;
    }

    try {
      _currentSource = DeviceFileSource(filePath);
      await _audioPlayer.setSource(_currentSource!);
      print("Main: Audio source set to $filePath");

      // --- MODIFICATION FOR ROBUST SEEK ---
      // Wait for the player to report its duration. This often indicates it's ready for seeking.
      // This also pre-populates _totalDuration.
      Duration? reportedDuration = await _audioPlayer.getDuration(); // This is an async call
      if (reportedDuration != null && mounted) {
        setState(() {
          _totalDuration = reportedDuration;
        });
        print("Main: Total duration received from player: $_totalDuration");
      } else {
        print("Main: Player did not report duration, or component unmounted.");
        // _totalDuration might still be updated by the onDurationChanged stream later.
      }
      // --- END MODIFICATION ---

      if (currTimestamp >= 0) {
        final seekTo = Duration(seconds: currTimestamp.round());
        print("Main: Attempting to seek to $seekTo (from global currTimestamp: $currTimestamp seconds).");

        // Ensure seek position is not beyond actual duration if known
        if (_totalDuration > Duration.zero && seekTo > _totalDuration) {
          print("Main: Warning - seek position $seekTo is beyond total duration $_totalDuration. Seeking to end.");
          await _audioPlayer.seek(_totalDuration);
        } else {
          await _audioPlayer.seek(seekTo);
        }
        // To be absolutely sure the position is registered, you might briefly play and pause
        // if issues persist, but usually seek itself is enough.
        // Example:
        // await _audioPlayer.resume();
        // await Future.delayed(Duration(milliseconds: 50)); // brief play
        // await _audioPlayer.pause();
        // But try without this first.
      } else {
        print("Main: currTimestamp ($currTimestamp) is negative, not seeking initially.");
      }

      await _loadNotesFromPantry();

    } catch (e,s) {
      print("Error setting audio source, getting duration, or seeking in Main: $e\n$s");
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error loading audio: $e")),
            );
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() { _isLoadingFile = false; });
      }
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

  void _addNote() async {
    final noteText = _noteInputController.text.trim();
    if (noteText.isNotEmpty) {
      final timeStr = _formatDuration(_currentPosition, forceHours: _totalDuration.inHours > 0);
      final newNote = "$timeStr-$deviceNameVar: $noteText";
      setState(() {
        _notes.insert(0, newNote);
      });
      _noteInputController.clear();
      FocusScope.of(context).unfocus();
      await _updatePantryNotesGlobal(List<String>.from(_notes));
    }
  }

  Future<void> _handlePlayPause() async {
    if (_audioPlayer.state == PlayerState.playing) { // Check current state
      await _audioPlayer.pause();
      await _updatePantryTimestampGlobal(_currentPosition.inSeconds.toDouble());
    } else {
      if (_currentSource != null) {
        if (_audioPlayer.state == PlayerState.completed) {
          await _audioPlayer.seek(Duration.zero); // Restart if completed
        }
        await _audioPlayer.play(_currentSource!);
      } else {
        print("Error: _currentSource is null in _handlePlayPause. Attempting to reinitialize.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Audio source error. Reloading...")),
          );
          await _initAudioAndLoadData(); // Attempt to reload and set source
          if (_currentSource != null && !_isLoadingFile) { // If reload successful
            await _audioPlayer.play(_currentSource!);
          }
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

  Future<void> _pauseAndSaveTimestamp() async {
    if (_audioPlayer.state == PlayerState.playing) {
      await _audioPlayer.pause();
    }
    await _updatePantryTimestampGlobal(_currentPosition.inSeconds.toDouble());
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose(); // Use dispose for full cleanup
    _noteInputController.dispose();
    _timeInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String bookTitle = currMP3.isNotEmpty ? p.basenameWithoutExtension(currMP3) : "Audio Player";

    return Scaffold(
      appBar: AppBar(
        title: Text(bookTitle, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.lightBlueAccent,
        foregroundColor: Colors.white,
        actions: [
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
              max: (_totalDuration == Duration.zero) ? 1.0 : _totalDuration.inMilliseconds.toDouble(), // Use 1.0 if duration is 0 to avoid max < min
              onChanged: (value) {
                if (_totalDuration > Duration.zero) {
                  _audioPlayer.seek(Duration(milliseconds: value.round()));
                }
              },
              activeColor: Colors.lightBlueAccent,
            ),
            Text(_formatDuration(_totalDuration, forceHours: _totalDuration.inHours > 0), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
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
                  icon: _isLoadingFile // Show spinner if initially loading file
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
            const SizedBox(height: 20),
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
                  return ListTile(
                    dense: true,
                    title: Text(_notes[index]),
                  );
                },
                separatorBuilder: (context, index) => const Divider(height:1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}