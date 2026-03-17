import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note.dart';
import '../models/device_position.dart';

/// Handles optional Supabase cloud sync.
///
/// All methods are no-ops and return empty results when Supabase is not
/// configured (i.e., when [isConfigured] is false).
///
/// Expected Supabase tables:
///
///   notes(id bigint PK, book_id text, chapter_index int,
///         position_seconds float8, device_name text, text text,
///         created_at timestamptz)
///
///   device_positions(book_id text, device_name text,
///                    chapter_index int, position_seconds float8,
///                    updated_at timestamptz,
///                    PRIMARY KEY (book_id, device_name))
class CloudRepository {
  SupabaseClient? _client;

  bool get isConfigured => _client != null;

  void configure(String url, String anonKey) {
    _client = SupabaseClient(url, anonKey);
  }

  void reset() {
    _client = null;
  }

  // ---------------------------------------------------------------------------
  // Notes
  // ---------------------------------------------------------------------------

  Future<List<Note>> fetchNotes(String bookId) async {
    if (!isConfigured) return [];
    try {
      final rows = await _client!
          .from('notes')
          .select()
          .eq('book_id', bookId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => Note.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      print('[CloudRepository] fetchNotes error: $e');
      return [];
    }
  }

  Future<void> upsertNote(Note note) async {
    if (!isConfigured) return;
    try {
      await _client!.from('notes').upsert(note.toMap());
    } catch (e) {
      print('[CloudRepository] upsertNote error: $e');
    }
  }

  Future<void> deleteNote(int id) async {
    if (!isConfigured) return;
    try {
      await _client!.from('notes').delete().eq('id', id);
    } catch (e) {
      print('[CloudRepository] deleteNote error: $e');
    }
  }

  Future<void> replaceAllNotes(String bookId, List<Note> notes) async {
    if (!isConfigured) return;
    try {
      await _client!.from('notes').delete().eq('book_id', bookId);
      if (notes.isNotEmpty) {
        await _client!.from('notes').insert(notes.map((n) => n.toMap()).toList());
      }
    } catch (e) {
      print('[CloudRepository] replaceAllNotes error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Device Positions
  // ---------------------------------------------------------------------------

  Future<List<DevicePosition>> fetchPositions(String bookId) async {
    if (!isConfigured) return [];
    try {
      final rows = await _client!
          .from('device_positions')
          .select()
          .eq('book_id', bookId);
      return (rows as List)
          .map((r) => DevicePosition.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      print('[CloudRepository] fetchPositions error: $e');
      return [];
    }
  }

  Future<void> upsertPosition(DevicePosition pos) async {
    if (!isConfigured) return;
    try {
      await _client!.from('device_positions').upsert(pos.toMap());
    } catch (e) {
      print('[CloudRepository] upsertPosition error: $e');
    }
  }

  Future<void> deletePosition(String bookId, String deviceName) async {
    if (!isConfigured) return;
    try {
      await _client!
          .from('device_positions')
          .delete()
          .eq('book_id', bookId)
          .eq('device_name', deviceName);
    } catch (e) {
      print('[CloudRepository] deletePosition error: $e');
    }
  }
}
