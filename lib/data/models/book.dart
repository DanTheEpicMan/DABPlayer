import 'dart:io';
import 'package:path/path.dart' as p;

/// Represents an audiobook — either a single MP3 or a folder of chapters.
class Book {
  final String title;
  final String id; // folder name or file name (used as the storage key)
  final bool isChaptered;
  final List<File> chapters;

  const Book({
    required this.title,
    required this.id,
    required this.isChaptered,
    required this.chapters,
  });

  /// Display name for a chapter at [index].
  String chapterDisplayName(int index) {
    if (index < 0 || index >= chapters.length) return 'Chapter ${index + 1}';
    return p.basenameWithoutExtension(chapters[index].path);
  }

  @override
  String toString() => 'Book(title: $title, chapters: ${chapters.length})';
}
