/// Formatting and parsing utilities for time/duration values.

/// Format a [Duration] as HH:MM:SS or MM:SS.
String formatDuration(Duration d, {bool forceHours = false}) {
  if (d < Duration.zero) d = Duration.zero;
  String two(int n) => n.toString().padLeft(2, '0');
  final mm = two(d.inMinutes.remainder(60));
  final ss = two(d.inSeconds.remainder(60));
  if (d.inHours > 0 || forceHours) {
    return '${two(d.inHours)}:$mm:$ss';
  }
  return '$mm:$ss';
}

/// Format [totalSeconds] (a double) as HH:MM:SS or MM:SS string.
String formatSeconds(double totalSeconds, {bool forceHours = false}) {
  return formatDuration(
    Duration(seconds: totalSeconds.round()),
    forceHours: forceHours,
  );
}

/// Parse a time string in formats: SS, MM:SS, or HH:MM:SS.
/// Also accepts '/' as an alternative separator.
/// Returns null if the input is invalid.
Duration? parseTimeInput(String input) {
  input = input.replaceAll('/', ':').trim();
  final parts = input.split(':');
  if (parts.isEmpty || parts.length > 3) return null;
  final ints = <int>[];
  for (final part in parts) {
    final val = int.tryParse(part);
    if (val == null) return null;
    ints.add(val);
  }
  int h = 0, m = 0, s = 0;
  switch (ints.length) {
    case 3:
      h = ints[0];
      m = ints[1];
      s = ints[2];
    case 2:
      m = ints[0];
      s = ints[1];
    case 1:
      s = ints[0];
    default:
      return null;
  }
  if (h < 0 || m < 0 || m >= 60 || s < 0 || s >= 60) return null;
  return Duration(hours: h, minutes: m, seconds: s);
}

/// Format a [Duration] as a human-readable string like "1h 23m 45s".
String formatDurationHuman(double totalSeconds) {
  final d = Duration(seconds: totalSeconds.round());
  if (d.inHours > 0) {
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m ${d.inSeconds.remainder(60)}s';
  }
  return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
}
