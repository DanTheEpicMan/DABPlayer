import 'package:flutter/material.dart';
import '../main.dart';
import '../audio/audio_handler.dart';
import '../data/models/book.dart';
import '../utils/file_utils.dart';
import '../theme.dart';

/// Scans the Audiobooks folder and shows the list of books.
class BookSelectScreen extends StatefulWidget {
  const BookSelectScreen({super.key});

  @override
  State<BookSelectScreen> createState() => _BookSelectScreenState();
}

class _BookSelectScreenState extends State<BookSelectScreen> {
  List<Book> _books = [];
  String? _audiobooksPath;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
      _books = [];
    });
    final path = await getAudiobooksDirectoryPath(context);
    if (path == null) {
      setState(() {
        _error = 'Could not access Audiobooks directory.';
        _loading = false;
      });
      return;
    }
    try {
      final books = await scanAudiobooks(path);
      setState(() {
        _audiobooksPath = path;
        _books = books;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error scanning audiobooks: $e';
        _loading = false;
      });
    }
  }

  void _selectBook(Book book) {
    currentBook = book;
    currentChapterIndex = 0;
    Navigator.pushReplacementNamed(context, '/devices');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audiobook Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_audiobooksPath != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Folder: $_audiobooksPath',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error.isNotEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
                ),
              ),
            )
          else if (_books.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.library_books_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No audiobooks found.\n\nPlace MP3 files (or folders of MP3 chapters) in:\n${_audiobooksPath ?? "~/Audiobooks"}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(top: 8),
                itemCount: _books.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (context, i) {
                  final book = _books[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: kPrimaryColor.withOpacity(0.15),
                      child: Icon(
                        book.isChaptered
                            ? Icons.folder_open
                            : Icons.headphones,
                        color: kPrimaryColor,
                      ),
                    ),
                    title: Text(book.title,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(book.isChaptered
                        ? '${book.chapters.length} chapters'
                        : 'Single file'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selectBook(book),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
