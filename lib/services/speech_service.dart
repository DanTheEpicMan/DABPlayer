import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps [SpeechToText] with a continuous listening cycle.
/// Automatically restarts when the OS stops listening (after a pause),
/// as long as [isSessionActive] is true.
class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _isSessionActive = false;

  String _sessionWords = '';
  String _currentWords = '';

  /// Accumulated transcript so far (all completed utterances).
  String get sessionWords => _sessionWords;

  /// In-progress partial transcript of the current utterance.
  String get currentWords => _currentWords;

  String get fullTranscript =>
      '$_sessionWords $_currentWords'.trim();

  bool get isSessionActive => _isSessionActive;

  /// Called whenever the transcript changes.
  VoidCallback? onTranscriptChanged;

  /// Called when the session ends and a final transcript is ready.
  void Function(String transcript)? onSessionComplete;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = await _speech.initialize(
      onError: _onError,
      onStatus: _onStatus,
    );
  }

  bool get isSupported => _initialized;

  /// Start a voice note session (continuous listening).
  Future<void> startSession() async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    _isSessionActive = true;
    _sessionWords = '';
    _currentWords = '';
    _startListening();
  }

  /// Stop the session and emit [onSessionComplete] with the full transcript.
  Future<void> stopSession() async {
    _isSessionActive = false;
    await _speech.stop();
    final transcript = fullTranscript;
    _sessionWords = '';
    _currentWords = '';
    if (transcript.isNotEmpty) {
      onSessionComplete?.call(transcript);
    }
  }

  Future<void> _startListening() async {
    await Future.delayed(const Duration(milliseconds: 50));
    await _speech.listen(
      onResult: _onResult,
      pauseFor: const Duration(seconds: 5),
      listenFor: const Duration(minutes: 5),
      partialResults: true,
      listenOptions: SpeechListenOptions(listenMode: ListenMode.dictation),
    );
  }

  void _onResult(SpeechRecognitionResult result) {
    _currentWords = result.recognizedWords;
    onTranscriptChanged?.call();
  }

  void _onStatus(String status) {
    if (status == 'done') {
      if (_currentWords.isNotEmpty) {
        _sessionWords = _sessionWords.isEmpty
            ? _currentWords
            : '$_sessionWords $_currentWords';
        _currentWords = '';
      }
      onTranscriptChanged?.call();

      if (_isSessionActive) {
        _startListening(); // Restart the listening cycle
      } else {
        final transcript = _sessionWords.trim();
        _sessionWords = '';
        if (transcript.isNotEmpty) {
          onSessionComplete?.call(transcript);
        }
      }
    }
  }

  void _onError(dynamic e) {
    debugPrint('[SpeechService] error: $e');
    if (_isSessionActive) {
      _isSessionActive = false;
      onTranscriptChanged?.call();
    }
  }

  void dispose() {
    _speech.cancel();
  }
}

// ignore: avoid_print
void debugPrint(String s) => print(s);
