import '../local_db.dart';
import 'package:drift/drift.dart';
import '../models/note.dart' as m;
import '../models/device_position.dart' as m;

/// Repository for all local SQLite operations.
/// This is the single source of truth when offline.
class LocalRepository {
  final AppDatabase _db;

  LocalRepository(this._db);

  // ---------------------------------------------------------------------------
  // Notes
  // ---------------------------------------------------------------------------

  /// Returns all notes for [bookId], newest first.
  Future<List<m.Note>> getNotesForBook(String bookId) async {
    final rows = await _db.notesForBook(bookId);
    return rows
        .map((r) => m.Note(
              id: r.id,
              bookId: r.bookId,
              chapterIndex: r.chapterIndex,
              positionSeconds: r.positionSeconds,
              deviceName: r.deviceName,
              text: r.text,
              createdAt: DateTime.parse(r.createdAt),
            ))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<m.Note> addNote(m.Note note) async {
    final id = await _db.insertNote(NotesCompanion.insert(
      bookId: note.bookId,
      chapterIndex: Value(note.chapterIndex),
      positionSeconds: Value(note.positionSeconds),
      deviceName: note.deviceName,
      text: note.text,
      createdAt: note.createdAt.toIso8601String(),
    ));
    return note.copyWith(id: id);
  }

  Future<void> updateNote(m.Note note) async {
    if (note.id == null) return;
    await _db.updateNote(NotesCompanion(
      id: Value(note.id!),
      bookId: Value(note.bookId),
      chapterIndex: Value(note.chapterIndex),
      positionSeconds: Value(note.positionSeconds),
      deviceName: Value(note.deviceName),
      text: Value(note.text),
      createdAt: Value(note.createdAt.toIso8601String()),
    ));
  }

  Future<void> deleteNote(int id) => _db.deleteNote(id);

  /// Replaces all notes for a book (used for cloud merge).
  Future<void> replaceAllNotes(String bookId, List<m.Note> notes) {
    final companions = notes
        .map((n) => NotesCompanion.insert(
              bookId: n.bookId,
              chapterIndex: Value(n.chapterIndex),
              positionSeconds: Value(n.positionSeconds),
              deviceName: n.deviceName,
              text: n.text,
              createdAt: n.createdAt.toIso8601String(),
            ))
        .toList();
    return _db.replaceAllNotesForBook(bookId, companions);
  }

  // ---------------------------------------------------------------------------
  // Device Positions
  // ---------------------------------------------------------------------------

  Future<List<m.DevicePosition>> getPositionsForBook(String bookId) async {
    final rows = await _db.positionsForBook(bookId);
    return rows
        .map((r) => m.DevicePosition(
              bookId: r.bookId,
              deviceName: r.deviceName,
              chapterIndex: r.chapterIndex,
              positionSeconds: r.positionSeconds,
              updatedAt: DateTime.parse(r.updatedAt),
            ))
        .toList();
  }

  Future<m.DevicePosition?> getPositionForDevice(
      String bookId, String deviceName) async {
    final row = await _db.positionForDevice(bookId, deviceName);
    if (row == null) return null;
    return m.DevicePosition(
      bookId: row.bookId,
      deviceName: row.deviceName,
      chapterIndex: row.chapterIndex,
      positionSeconds: row.positionSeconds,
      updatedAt: DateTime.parse(row.updatedAt),
    );
  }

  Future<void> savePosition(m.DevicePosition pos) {
    return _db.upsertPosition(DevicePositionsCompanion.insert(
      bookId: pos.bookId,
      deviceName: pos.deviceName,
      chapterIndex: Value(pos.chapterIndex),
      positionSeconds: Value(pos.positionSeconds),
      updatedAt: pos.updatedAt.toIso8601String(),
    ));
  }

  Future<void> deletePosition(String bookId, String deviceName) =>
      _db.deletePosition(bookId, deviceName);
}
