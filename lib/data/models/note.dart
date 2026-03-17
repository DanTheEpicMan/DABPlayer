/// A timestamped note attached to a specific position in a book.
class Note {
  final int? id; // null before persisted
  final String bookId;
  final int chapterIndex;
  final double positionSeconds;
  final String deviceName;
  final String text;
  final DateTime createdAt;

  const Note({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.positionSeconds,
    required this.deviceName,
    required this.text,
    required this.createdAt,
  });

  /// Returns the formatted note string as displayed in the UI.
  String get displayText => text;

  /// Full label shown in the notes list (e.g. "Ch 2 @ 05:34-MyPhone: ...")
  String get label {
    final minutes = (positionSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (positionSeconds.round() % 60).toString().padLeft(2, '0');
    final timeStr = '$minutes:$seconds';
    if (chapterIndex >= 0) {
      return 'Ch ${chapterIndex + 1} @ $timeStr-$deviceName: $text';
    }
    return '$timeStr-$deviceName: $text';
  }

  Note copyWith({
    int? id,
    String? bookId,
    int? chapterIndex,
    double? positionSeconds,
    String? deviceName,
    String? text,
    DateTime? createdAt,
  }) {
    return Note(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      deviceName: deviceName ?? this.deviceName,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'book_id': bookId,
        'chapter_index': chapterIndex,
        'position_seconds': positionSeconds,
        'device_name': deviceName,
        'text': text,
        'created_at': createdAt.toIso8601String(),
      };

  factory Note.fromMap(Map<String, dynamic> map, {int? id}) => Note(
        id: id ?? map['id'] as int?,
        bookId: map['book_id'] as String,
        chapterIndex: map['chapter_index'] as int,
        positionSeconds: (map['position_seconds'] as num).toDouble(),
        deviceName: map['device_name'] as String,
        text: map['text'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
