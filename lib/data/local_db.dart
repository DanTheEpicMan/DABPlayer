import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'local_db.g.dart';

// ---------------------------------------------------------------------------
// TABLE DEFINITIONS
// ---------------------------------------------------------------------------

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer()();
  RealColumn get positionSeconds => real()();
  TextColumn get deviceName => text()();
  TextColumn get text => text()();
  TextColumn get createdAt => text()(); // ISO-8601

  @override
  String get tableName => 'notes';
}

class DevicePositions extends Table {
  TextColumn get bookId => text()();
  TextColumn get deviceName => text()();
  IntColumn get chapterIndex => integer()();
  RealColumn get positionSeconds => real()();
  TextColumn get updatedAt => text()(); // ISO-8601

  @override
  Set<Column> get primaryKey => {bookId, deviceName};

  @override
  String get tableName => 'device_positions';
}

// ---------------------------------------------------------------------------
// DATABASE
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [Notes, DevicePositions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ----- Notes -----

  Future<List<Note>> notesForBook(String bookId) =>
      (select(notes)..where((t) => t.bookId.equals(bookId))).get();

  Future<int> insertNote(NotesCompanion entry) => into(notes).insert(entry);

  Future<bool> updateNote(NotesCompanion entry) =>
      update(notes).replace(entry);

  Future<int> deleteNote(int id) =>
      (delete(notes)..where((t) => t.id.equals(id))).go();

  Future<void> replaceAllNotesForBook(
      String bookId, List<NotesCompanion> entries) async {
    await transaction(() async {
      await (delete(notes)..where((t) => t.bookId.equals(bookId))).go();
      await batch((b) => b.insertAll(notes, entries));
    });
  }

  // ----- Device Positions -----

  Future<List<DevicePosition>> positionsForBook(String bookId) =>
      (select(devicePositions)..where((t) => t.bookId.equals(bookId))).get();

  Future<DevicePosition?> positionForDevice(
      String bookId, String deviceName) async {
    final q = select(devicePositions)
      ..where((t) =>
          t.bookId.equals(bookId) & t.deviceName.equals(deviceName));
    return q.getSingleOrNull();
  }

  Future<void> upsertPosition(DevicePositionsCompanion entry) =>
      into(devicePositions).insertOnConflictUpdate(entry);

  Future<int> deletePosition(String bookId, String deviceName) =>
      (delete(devicePositions)
            ..where((t) =>
                t.bookId.equals(bookId) &
                t.deviceName.equals(deviceName)))
          .go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'dabplayer.db'));
    return SqfliteQueryExecutor.inDatabaseFolder(path: file.path);
  });
}
