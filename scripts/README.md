# DABPlayer Build Scripts

Quick build scripts for each supported platform.

## Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) installed and on your PATH
- For Android: Android SDK + NDK (via Android Studio or `sdkmanager`)
- For iOS: macOS + Xcode 15+
- For Linux: `libgtk-3-dev`, `liblzma-dev`, `libpthread-stubs0-dev`

---

## Android

```bash
chmod +x scripts/build_android.sh

# Debug APK (sideload / test)
./scripts/build_android.sh

# Release APK + AAB (Play Store)
./scripts/build_android.sh release
```

**Install debug APK directly:**
```bash
adb install build/app/outputs/flutter-apk/app-debug.apk
```

---

## Linux Desktop

```bash
chmod +x scripts/build_linux.sh
./scripts/build_linux.sh
```

Run the app:
```bash
./build/linux/x64/release/bundle/dabplayer
```

---

## iOS

```bash
chmod +x scripts/build_ios.sh
./scripts/build_ios.sh
```

Then open `ios/Runner.xcworkspace` in Xcode to set your signing team and deploy to a device or simulator.

---

## Cloud Sync Setup (Supabase)

To enable optional cross-device sync:

1. Create a free project at [supabase.com](https://supabase.com)
2. In the Supabase SQL editor, run:

```sql
create table notes (
  id bigint generated always as identity primary key,
  book_id text not null,
  chapter_index int not null default 0,
  position_seconds float8 not null default 0,
  device_name text not null,
  text text not null,
  created_at timestamptz not null default now()
);

create table device_positions (
  book_id text not null,
  device_name text not null,
  chapter_index int not null default 0,
  position_seconds float8 not null default 0,
  updated_at timestamptz not null default now(),
  primary key (book_id, device_name)
);

-- Enable RLS and allow all (anon key access) — tighten as needed
alter table notes enable row level security;
alter table device_positions enable row level security;

create policy "allow all" on notes for all using (true);
create policy "allow all" on device_positions for all using (true);
```

3. Copy your project URL and `anon` public key from **Settings → API**
4. In the DABPlayer app, go to **Settings**, enable Cloud Sync, and paste those values.
