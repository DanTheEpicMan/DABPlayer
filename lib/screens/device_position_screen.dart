import 'package:flutter/material.dart';
import '../main.dart';
import '../audio/audio_handler.dart';
import '../data/models/book.dart';
import '../data/models/device_position.dart';
import '../utils/time_utils.dart';
import '../theme.dart';

/// Shows saved positions for all devices for the current book.
/// User picks which device's position to resume from.
class DevicePositionScreen extends StatefulWidget {
  const DevicePositionScreen({super.key});

  @override
  State<DevicePositionScreen> createState() => _DevicePositionScreenState();
}

class _DevicePositionScreenState extends State<DevicePositionScreen> {
  List<DevicePosition> _positions = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final book = currentBook;
      if (book == null) {
        setState(() {
          _error = 'No book selected.';
          _loading = false;
        });
        return;
      }

      var positions = await syncManager.getPositionsForBook(book.id);

      // Ensure current device has an entry
      if (!positions.any((p) => p.deviceName == deviceNameVar)) {
        final newPos = DevicePosition(
          bookId: book.id,
          deviceName: deviceNameVar,
          chapterIndex: 0,
          positionSeconds: 0.0,
          updatedAt: DateTime.now(),
        );
        await syncManager.savePosition(newPos);
        positions = [...positions, newPos];
      }

      // Sort: current device first, then alphabetical
      positions.sort((a, b) {
        if (a.deviceName == deviceNameVar) return -1;
        if (b.deviceName == deviceNameVar) return 1;
        return a.deviceName.compareTo(b.deviceName);
      });

      setState(() {
        _positions = positions;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading positions: $e';
        _loading = false;
      });
    }
  }

  Future<void> _selectPosition(DevicePosition pos) async {
    // Save selection for current device
    final updated = DevicePosition(
      bookId: pos.bookId,
      deviceName: deviceNameVar,
      chapterIndex: pos.chapterIndex,
      positionSeconds: pos.positionSeconds,
      updatedAt: DateTime.now(),
    );
    await syncManager.savePosition(updated);
    currentChapterIndex = pos.chapterIndex;
    if (mounted) Navigator.pushReplacementNamed(context, '/player');
  }

  void _showEditDialog(DevicePosition pos) {
    int selectedChapter = pos.chapterIndex;
    final timeCtrl = TextEditingController(
        text: formatSeconds(pos.positionSeconds).replaceAll(':', ':'));
    final book = currentBook;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDs) => AlertDialog(
          title: Text("Edit '${pos.deviceName}'"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (book != null && book.isChaptered)
                DropdownButtonFormField<int>(
                  value: selectedChapter,
                  items: List.generate(book.chapters.length, (i) {
                    return DropdownMenuItem(
                      value: i,
                      child: Text(
                        'Chapter ${i + 1}: ${book.chapterDisplayName(i)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                  onChanged: (v) {
                    if (v != null) setDs(() => selectedChapter = v);
                  },
                  decoration: const InputDecoration(labelText: 'Chapter'),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Time',
                  hintText: 'MM:SS or HH:MM:SS',
                  border: OutlineInputBorder(),
                ),
                autofocus: book == null || !book.isChaptered,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final dur = parseTimeInput(timeCtrl.text);
                if (dur == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid time format')),
                  );
                  return;
                }
                final updated = DevicePosition(
                  bookId: pos.bookId,
                  deviceName: pos.deviceName,
                  chapterIndex: selectedChapter,
                  positionSeconds: dur.inSeconds.toDouble(),
                  updatedAt: DateTime.now(),
                );
                await syncManager.savePosition(updated);
                if (!mounted) return;
                Navigator.of(ctx).pop();
                _loadPositions();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePosition(DevicePosition pos) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Position?'),
        content: Text(
            "Remove saved position for '${pos.deviceName}'? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await syncManager.deletePosition(pos.bookId, pos.deviceName);
      _loadPositions();
    }
  }

  String _subtitle(DevicePosition pos, Book? book) {
    final time = formatDurationHuman(pos.positionSeconds);
    if (book != null && book.isChaptered) {
      return 'Chapter ${pos.chapterIndex + 1} · $time';
    }
    return 'Position: $time';
  }

  @override
  Widget build(BuildContext context) {
    final book = currentBook;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          book != null ? "'${book.title}' — Devices" : 'Select Position',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPositions,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.library_books),
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/books'),
            tooltip: 'Back to books',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPositions,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: _positions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (ctx, i) {
                    final pos = _positions[i];
                    final isCurrent = pos.deviceName == deviceNameVar;
                    return Dismissible(
                      key: Key('${pos.bookId}_${pos.deviceName}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete,
                            color: Colors.white),
                      ),
                      onDismissed: (_) => _deletePosition(pos),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCurrent
                              ? kPrimaryColor
                              : kPrimaryColor.withOpacity(0.15),
                          child: Icon(
                            isCurrent
                                ? Icons.phonelink_ring
                                : Icons.devices_other,
                            color: isCurrent
                                ? Colors.white
                                : kPrimaryColor,
                          ),
                        ),
                        title: Text(
                          pos.deviceName,
                          style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                        ),
                        subtitle: Text(_subtitle(pos, book)),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit position',
                          onPressed: () => _showEditDialog(pos),
                        ),
                        onTap: () => _selectPosition(pos),
                      ),
                    );
                  },
                ),
    );
  }
}
