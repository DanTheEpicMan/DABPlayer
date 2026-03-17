import 'package:flutter/material.dart';
import '../main.dart';
import '../audio/audio_handler.dart';
import '../theme.dart';

/// Previous/next chapter buttons + chapter indicator.
/// Returns an empty SizedBox if the book is not chaptered.
class ChapterControls extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const ChapterControls({
    super.key,
    required this.isLoading,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final book = currentBook;
    if (book == null || !book.isChaptered) {
      return const SizedBox(height: 0);
    }

    final chapterCount = book.chapters.length;
    final idx = currentChapterIndex;

    return SizedBox(
      height: 60,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous),
            iconSize: 32,
            onPressed: (isLoading || idx == 0) ? null : onPrevious,
            tooltip: 'Previous Chapter',
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Chapter ${idx + 1} / $chapterCount',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  book.chapterDisplayName(idx),
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            iconSize: 32,
            onPressed:
                (isLoading || idx >= chapterCount - 1) ? null : onNext,
            tooltip: 'Next Chapter',
          ),
        ],
      ),
    );
  }
}
