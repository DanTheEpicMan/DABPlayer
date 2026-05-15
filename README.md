# DABPlayer
Distributed AudioBook Player
Sync Across Devices (optional), Take Notes, all without always needing internet access.

## Human Written:
This entire app is just a way for me to solve the issue of listening to audiobooks (in mp3 format, either pulled form YouTube or pirated) without having to stream an MP3 from a home server (or even have a homeserver/something publically facing). As such, this better version of audible was born. 
It solved the biggest issue I faced when listening to audiobooks, not being able to 1) sync accross devices efficiently, 2) not being able to take notes when listening to a book (espetually saying notes witch the build in WhisperAI model can do). I had AI write most of the app and I basically guided the featurs/did testing of app functionality. Im sure its horrible, from a security, preformance, and bug standpoint, but its not very critical and it serves the usecase pretty well.

## AI Generated from here:
Offline-first audiobook player with local SQLite storage, optional Supabase cloud sync, and on-device Whisper transcription.

### Features

- **Offline-First**: Books and notes are stored locally.
- **Sync**: Optional cloud sync via Supabase.
- **Car Mode**: Large-tap interface for safe recording during drives.
- **Local Whisper AI**: 100% on-device speech-to-text using `whisper.cpp` (no APIs/internet required).
- **Multi-platform**: Supports Android, Linux, and Windows.

### Setup Instructions

#### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- For Android: Android Studio & NDK.
- For Linux: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`.
- For Windows: Visual Studio with "Desktop development with C++" workload.

#### 2. Whisper Model Setup
The app uses a local Whisper model. 
- Download the `ggml-tiny.en.bin` model (approx 75MB) from [HuggingFace](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin).
- Place it in the `assets/models/` directory.

#### 3. Build & Run
You can use the helper scripts in `./scripts`:
- **Linux**: `./scripts/build_linux.sh`
- **Windows**: `./scripts/build_windows.bat`
- **Android**: `flutter build apk`

### GitHub Release Distribution

1. **Versioning**: Update the `version` in `pubspec.yaml`.
2. **Build APK**: Run `./scripts/publish_prep.sh` to generate the release APK.
3. **GitHub**: Create a new Release in your repo and attach `build/app/outputs/flutter-apk/app-release.apk`.
4. **Sideload**: Download the APK on your phone and grant "Install Unknown Apps" permission to your browser.

### Supabase Cloud Sync (Optional)
1. Create a Supabase project.
2. Run the SQL schema found in the app's **Settings** screen info box.
3. Toggle "Cloud Sync" in the app settings and enter your URL/Key.
