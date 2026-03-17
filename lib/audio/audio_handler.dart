import 'dart:io';
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path/path.dart' as p;
import '../data/models/book.dart';

// Global mutable pointer to current book/chapter — shared between audio
// handler and UI. Kept intentionally minimal; the UI owns chapter navigation.
Book? currentBook;
int currentChapterIndex = 0;

/// Background audio handler used by [audio_service].
///
/// Implements hardware media button controls (Bluetooth car buttons, headset
/// buttons, lock-screen controls) via [BaseAudioHandler] + [SeekHandler].
///
/// Key Android behaviour:
///   - [skipToPrevious] / [skipToNext] appear in the notification and respond
///     to Bluetooth AVRCP commands from cars.
///   - [androidCompactActionIndices] sets which 3 actions show on the
///     compact notification (rewind, play/pause, forward).
class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = ja.AudioPlayer();
  int _currentChapterIndex = 0;

  MyAudioHandler() {
    // Pipe player events into the playback state broadcast stream.
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Auto-advance to next chapter on completion.
    _player.processingStateStream.listen((state) {
      if (state == ja.ProcessingState.completed) {
        if (currentBook != null &&
            _currentChapterIndex < currentBook!.chapters.length - 1) {
          skipToNext();
        }
      }
    });
  }

  /// Load a chapter file into the player. Call from UI when switching chapters.
  Future<void> loadChapter(int chapterIndex, {Duration? startPosition}) async {
    if (currentBook == null ||
        chapterIndex < 0 ||
        chapterIndex >= currentBook!.chapters.length) {
      return;
    }
    _currentChapterIndex = chapterIndex;
    currentChapterIndex = chapterIndex;

    final chapterFile = currentBook!.chapters[chapterIndex];
    final duration = await _player.setFilePath(
      chapterFile.path,
      initialPosition: startPosition,
    );

    mediaItem.add(MediaItem(
      id: chapterFile.path,
      title: currentBook!.chapterDisplayName(chapterIndex),
      artist: currentBook!.title,
      album: currentBook!.title,
      duration: duration ?? Duration.zero,
    ));
  }

  // ---------------------------------------------------------------------------
  // AudioHandler overrides — these respond to hardware/OS media controls
  // ---------------------------------------------------------------------------

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (currentBook != null &&
        _currentChapterIndex < currentBook!.chapters.length - 1) {
      await loadChapter(_currentChapterIndex + 1);
      await play();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // If more than 5s into a chapter, restart it; otherwise go to previous.
    if (_player.position.inSeconds > 5) {
      await seek(Duration.zero);
    } else if (_currentChapterIndex > 0) {
      await loadChapter(_currentChapterIndex - 1);
      await play();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await playbackState.firstWhere(
        (s) => s.processingState == AudioProcessingState.idle);
  }

  // Stubs required by some Android implementations
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {}

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {}

  /// Transforms a just_audio [PlaybackEvent] into an [audio_service] state.
  PlaybackState _transformEvent(ja.PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
      },
      // Compact notification: prev, play/pause, next
      androidCompactActionIndices: const [0, 2, 4],
      processingState: const {
        ja.ProcessingState.idle: AudioProcessingState.idle,
        ja.ProcessingState.loading: AudioProcessingState.loading,
        ja.ProcessingState.buffering: AudioProcessingState.buffering,
        ja.ProcessingState.ready: AudioProcessingState.ready,
        ja.ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  /// Expose the underlying player for UI stream subscriptions.
  ja.AudioPlayer get player => _player;
}
