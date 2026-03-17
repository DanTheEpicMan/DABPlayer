import '../models/note.dart';
import '../models/device_position.dart';
import 'local_repository.dart';
import 'cloud_repository.dart';

/// Orchestrates reads/writes between the local SQLite DB and optional cloud.
///
/// Strategy: **local-first**.
/// - All writes go to local immediately, then cloud async (fire-and-forget).
/// - On book open, a background cloud pull is triggered; local is merged
///   with remote by taking the most recent position per device and
///   unioning notes (deduped by createdAt + deviceName + text).
class SyncManager {
  final LocalRepository local;
  final CloudRepository cloud;

  SyncManager({required this.local, required this.cloud});

  bool get hasCloud => cloud.isConfigured;

  // ---------------------------------------------------------------------------
  // Notes
  // ---------------------------------------------------------------------------

  Future<List<Note>> getNotesForBook(String bookId) async {
    final localNotes = await local.getNotesForBook(bookId);
    if (!hasCloud) return localNotes;

    // Background merge — don't block UI
    _mergeNotesInBackground(bookId, localNotes);
    return localNotes;
  }

  Future<void> _mergeNotesInBackground(
      String bookId, List<Note> localNotes) async {
    try {
      final remoteNotes = await cloud.fetchNotes(bookId);
      if (remoteNotes.isEmpty) return;

      // Union by (createdAt, deviceName, text) — naïve dedup
      final merged = <String, Note>{};
      for (final n in [...localNotes, ...remoteNotes]) {
        final key =
            '${n.createdAt.toIso8601String()}_${n.deviceName}_${n.text}';
        merged[key] = n;
      }
      final mergedList = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      await local.replaceAllNotes(bookId, mergedList);
    } catch (e) {
      print('[SyncManager] _mergeNotesInBackground error: $e');
    }
  }

  Future<Note> addNote(Note note) async {
    final saved = await local.addNote(note);
    if (hasCloud) cloud.upsertNote(saved).ignore();
    return saved;
  }

  Future<void> updateNote(Note note) async {
    await local.updateNote(note);
    if (hasCloud) cloud.upsertNote(note).ignore();
  }

  Future<void> deleteNote(Note note) async {
    if (note.id != null) await local.deleteNote(note.id!);
    if (hasCloud && note.id != null) cloud.deleteNote(note.id!).ignore();
  }

  // ---------------------------------------------------------------------------
  // Positions
  // ---------------------------------------------------------------------------

  Future<List<DevicePosition>> getPositionsForBook(String bookId) async {
    final localPositions = await local.getPositionsForBook(bookId);
    if (!hasCloud) return localPositions;

    // Merge remote positions in background
    _mergePositionsInBackground(bookId, localPositions);
    return localPositions;
  }

  Future<void> _mergePositionsInBackground(
      String bookId, List<DevicePosition> localPositions) async {
    try {
      final remotePositions = await cloud.fetchPositions(bookId);
      for (final remote in remotePositions) {
        final local_ =
            localPositions.where((p) => p.deviceName == remote.deviceName);
        if (local_.isEmpty ||
            remote.updatedAt.isAfter(local_.first.updatedAt)) {
          await local.savePosition(remote);
        }
      }
    } catch (e) {
      print('[SyncManager] _mergePositionsInBackground error: $e');
    }
  }

  Future<void> savePosition(DevicePosition pos) async {
    await local.savePosition(pos);
    if (hasCloud) cloud.upsertPosition(pos).ignore();
  }

  Future<void> deletePosition(String bookId, String deviceName) async {
    await local.deletePosition(bookId, deviceName);
    if (hasCloud) cloud.deletePosition(bookId, deviceName).ignore();
  }

  Future<DevicePosition?> getPositionForDevice(
          String bookId, String deviceName) =>
      local.getPositionForDevice(bookId, deviceName);
}
