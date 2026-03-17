import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../main.dart';
import '../audio/audio_handler.dart';
import '../data/models/note.dart';
import '../data/models/device_position.dart';
import '../services/speech_service.dart';
import '../utils/time_utils.dart';
import '../widgets/playback_controls.dart';
import '../widgets/chapter_controls.dart';
import '../widgets/notes_panel.dart';
import '../widgets/car_mode_panel.dart';
import '../theme.dart';
import 'package:path/path.dart' as p;

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isLoading = true;
  bool _isCarMode = false;
  List<Note> _notes = [];
  final _noteCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();

  Timer? _saveTimer;
  late SpeechService _speech;
  bool _voiceSupported = false;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _speech = SpeechService();
    _speech.onTranscriptChanged = () => setState(() {});
    _speech.onSessionComplete = (transcript) async {
      await _saveNote(transcript);
      if (mounted && !_isCarMode) {
        // Resume audio after voice note in regular mode
        await audioHandler.play();
      }
    };

    _init();

    // Save position whenever playback pauses
    audioHandler.playbackState.listen((state) {
      if (!state.playing) _scheduleSave();
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _noteCtrl.dispose();
    _timeCtrl.dispose();
    _speech.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Init
  // -------------------------------------------------------------------------

  Future<void> _init() async {
    if (currentBook == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/books');
        }
      });
      return;
    }

    // Init speech on supported platforms
    if (Platform.isAndroid || Platform.isIOS) {
      await _speech.initialize();
      if (mounted) setState(() => _voiceSupported = _speech.isSupported);
    }

    // Load the chapter
    final savedPos = await syncManager.getPositionForDevice(
        currentBook!.id, deviceNameVar);
    final startChapter = savedPos?.chapterIndex ?? currentChapterIndex;
    final startSecs = savedPos?.positionSeconds ?? 0.0;

    await _loadChapter(startChapter,
        seekTo: Duration(seconds: startSecs.round()), autoPlay: false);
    await _loadNotes();
  }

  // -------------------------------------------------------------------------
  // Audio control
  // -------------------------------------------------------------------------

  Future<void> _loadChapter(int index,
      {Duration? seekTo, bool autoPlay = true}) async {
    if (currentBook == null ||
        index < 0 ||
        index >= currentBook!.chapters.length) return;

    if (mounted) setState(() => _isLoading = true);
    try {
      await (audioHandler as MyAudioHandler)
          .loadChapter(index, startPosition: seekTo);
      if (autoPlay) await audioHandler.play();
    } catch (e) {
      debugPrint('PlayerScreen: load chapter error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _seekRelative(Duration offset) {
    final pos = audioHandler.playbackState.value.updatePosition + offset;
    audioHandler.seek(pos < Duration.zero ? Duration.zero : pos);
  }

  Future<void> _handlePlayPause() async {
    final playing = audioHandler.playbackState.value.playing;
    if (playing) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
  }

  void _nextChapter({bool? autoPlay}) {
    final play = autoPlay ?? audioHandler.playbackState.value.playing;
    _loadChapter(currentChapterIndex + 1, autoPlay: play);
  }

  void _previousChapter({bool? autoPlay}) {
    final play = autoPlay ?? audioHandler.playbackState.value.playing;
    _loadChapter(currentChapterIndex - 1, autoPlay: play);
  }

  // -------------------------------------------------------------------------
  // Position saving
  // -------------------------------------------------------------------------

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 3), _savePosition);
  }

  Future<void> _savePosition() async {
    if (currentBook == null) return;
    final pos = audioHandler.playbackState.value.updatePosition;
    await syncManager.savePosition(DevicePosition(
      bookId: currentBook!.id,
      deviceName: deviceNameVar,
      chapterIndex: currentChapterIndex,
      positionSeconds: pos.inSeconds.toDouble(),
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _pauseAndSave() async {
    _saveTimer?.cancel();
    if (audioHandler.playbackState.value.playing) await audioHandler.pause();
    await _savePosition();
  }

  // -------------------------------------------------------------------------
  // Notes
  // -------------------------------------------------------------------------

  Future<void> _loadNotes() async {
    if (currentBook == null) return;
    final notes = await syncManager.getNotesForBook(currentBook!.id);
    if (mounted) setState(() => _notes = notes);
  }

  Future<void> _saveNote(String text) async {
    if (currentBook == null || text.trim().isEmpty) return;
    final pos = audioHandler.playbackState.value.updatePosition;
    final total = audioHandler.mediaItem.value?.duration ?? Duration.zero;
    final note = Note(
      bookId: currentBook!.id,
      chapterIndex: currentChapterIndex,
      positionSeconds: pos.inSeconds.toDouble(),
      deviceName: deviceNameVar,
      text: text.trim(),
      createdAt: DateTime.now(),
    );
    final saved = await syncManager.addNote(note);
    if (mounted) setState(() => _notes.insert(0, saved));
  }

  Future<void> _addTextNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    await _saveNote(text);
    _noteCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await syncManager.deleteNote(note);
    if (mounted) setState(() => _notes.remove(note));
  }

  void _editNote(Note note) {
    // Extract editable text from label
    final sep = ': ';
    final idx = note.label.indexOf(sep);
    final content =
        idx != -1 ? note.label.substring(idx + sep.length) : note.text;
    final ctrl = TextEditingController(text: content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Note'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          decoration: const InputDecoration(
              border: OutlineInputBorder(), labelText: 'Note content'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final updated = note.copyWith(text: ctrl.text.trim());
              await syncManager.updateNote(updated);
              if (mounted) {
                setState(() {
                  final i = _notes.indexWhere((n) => n.id == note.id);
                  if (i != -1) _notes[i] = updated;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Voice / Car mode
  // -------------------------------------------------------------------------

  Future<void> _toggleVoice() async {
    if (_speech.isSessionActive) {
      await _speech.stopSession();
      setState(() {});
    } else {
      // Pause audio before recording
      if (audioHandler.playbackState.value.playing) {
        await audioHandler.pause();
      }
      await _speech.startSession();
      setState(() {});
    }
  }

  void _toggleCarMode() {
    setState(() => _isCarMode = !_isCarMode);
    if (_isCarMode) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  // -------------------------------------------------------------------------
  // Seek dialogs
  // -------------------------------------------------------------------------

  void _showSeekDialog() {
    final book = currentBook;
    if (book != null && book.isChaptered) {
      _showChapterSeekDialog();
      return;
    }
    final pos = audioHandler.playbackState.value.updatePosition;
    final total =
        audioHandler.mediaItem.value?.duration ?? Duration.zero;
    _timeCtrl.text = formatDuration(pos, forceHours: total.inHours > 0);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seek to Time'),
        content: TextField(
          controller: _timeCtrl,
          keyboardType: TextInputType.datetime,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'MM:SS or HH:MM:SS',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            child: const Text('Seek'),
            onPressed: () {
              final d = parseTimeInput(_timeCtrl.text);
              if (d != null) {
                if (d <= total && d >= Duration.zero) {
                  audioHandler.seek(d);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Out of range')));
                }
              }
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showChapterSeekDialog() {
    int sel = currentChapterIndex;
    _timeCtrl.text = '00:00';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDs) => AlertDialog(
          title: const Text('Seek to Chapter & Time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: sel,
                items: List.generate(
                    currentBook!.chapters.length,
                    (i) => DropdownMenuItem(
                        value: i,
                        child: Text(
                          'Chapter ${i + 1}: ${currentBook!.chapterDisplayName(i)}',
                          overflow: TextOverflow.ellipsis,
                        ))),
                onChanged: (v) {
                  if (v != null) setDs(() => sel = v);
                },
                decoration: const InputDecoration(labelText: 'Chapter'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _timeCtrl,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                    labelText: 'Time',
                    hintText: 'MM:SS or HH:MM:SS',
                    border: OutlineInputBorder()),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            TextButton(
              child: const Text('Seek'),
              onPressed: () {
                final d = parseTimeInput(_timeCtrl.text);
                if (d != null) {
                  final wasPlaying =
                      audioHandler.playbackState.value.playing;
                  _loadChapter(sel,
                      seekTo: d, autoPlay: wasPlaying);
                }
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final book = currentBook;
    if (book == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(book.title, overflow: TextOverflow.ellipsis),
        actions: [
          // Car mode toggle (requires voice support)
          if (_voiceSupported)
            IconButton(
              icon: Icon(_isCarMode ? Icons.notes : Icons.directions_car),
              tooltip: _isCarMode ? 'Exit Car Mode' : 'Car Mode',
              onPressed: _toggleCarMode,
            ),
          // Seek
          IconButton(
            icon: const Icon(Icons.timer_outlined),
            tooltip: 'Seek to time',
            onPressed: _isLoading ? null : _showSeekDialog,
          ),
          // Device positions
          IconButton(
            icon: const Icon(Icons.devices_other_outlined),
            tooltip: 'Device positions',
            onPressed: () async {
              await _pauseAndSave();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/devices');
              }
            },
          ),
          // Book list
          IconButton(
            icon: const Icon(Icons.library_books_outlined),
            tooltip: 'Choose audiobook',
            onPressed: () async {
              await _pauseAndSave();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/books');
              }
            },
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () async {
              await _pauseAndSave();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/settings');
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  // Playback slider + buttons
                  PlaybackControls(
                    isLoading: _isLoading,
                    onSeekRelative: (offset) async {
                      _seekRelative(offset);
                    },
                    onPlayPause: _handlePlayPause,
                    onSeekEnd: _scheduleSave,
                  ),
                  const SizedBox(height: 4),
                  // Chapter nav (hidden for single-file books)
                  ChapterControls(
                    isLoading: _isLoading,
                    onPrevious: _previousChapter,
                    onNext: _nextChapter,
                  ),
                  const SizedBox(height: 8),
                  // Either notes or car mode panel
                  if (_isCarMode)
                    CarModePanel(
                      isRecording: _speech.isSessionActive,
                      transcript: _speech.fullTranscript,
                      onTap: _toggleVoice,
                    )
                  else
                    Expanded(
                      child: NotesPanel(
                        notes: _notes,
                        isLoading: _isLoading,
                        voiceSupported: _voiceSupported,
                        noteController: _noteCtrl,
                        onAdd: _addTextNote,
                        onVoiceTap: _toggleVoice,
                        onDelete: _deleteNote,
                        onEdit: _editNote,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

void debugPrint(String s) => print(s);
