/// Records where a specific named device left off in a book.
class DevicePosition {
  final String bookId;
  final String deviceName;
  final int chapterIndex;
  final double positionSeconds;
  final DateTime updatedAt;

  const DevicePosition({
    required this.bookId,
    required this.deviceName,
    required this.chapterIndex,
    required this.positionSeconds,
    required this.updatedAt,
  });

  DevicePosition copyWith({
    String? bookId,
    String? deviceName,
    int? chapterIndex,
    double? positionSeconds,
    DateTime? updatedAt,
  }) {
    return DevicePosition(
      bookId: bookId ?? this.bookId,
      deviceName: deviceName ?? this.deviceName,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'book_id': bookId,
        'device_name': deviceName,
        'chapter_index': chapterIndex,
        'position_seconds': positionSeconds,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory DevicePosition.fromMap(Map<String, dynamic> map) => DevicePosition(
        bookId: map['book_id'] as String,
        deviceName: map['device_name'] as String,
        chapterIndex: (map['chapter_index'] as num).toInt(),
        positionSeconds: (map['position_seconds'] as num).toDouble(),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  @override
  String toString() =>
      'DevicePosition($deviceName: ch=$chapterIndex, pos=${positionSeconds}s)';
}
