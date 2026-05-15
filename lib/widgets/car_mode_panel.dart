import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/local_whisper_service.dart';
import '../theme.dart';

/// Large-tap car mode UI for non-blocking voice notes.
/// Transcription happens in the background via callbacks to the parent.
class CarModePanel extends StatefulWidget {
  final Future<void> Function(String) onSaveNote;
  final VoidCallback onPauseRequested;
  final VoidCallback onResumeRequested;
  final VoidCallback onTranscriptionStart;
  final VoidCallback onTranscriptionEnd;

  const CarModePanel({
    super.key,
    required this.onSaveNote,
    required this.onPauseRequested,
    required this.onResumeRequested,
    required this.onTranscriptionStart,
    required this.onTranscriptionEnd,
  });

  @override
  State<CarModePanel> createState() => _CarModePanelState();
}

class _CarModePanelState extends State<CarModePanel> {
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  String? _recordPath;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    // Warm up whisper engine
    LocalWhisperService.init();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_isRecording) {
      // Stop recording
      setState(() => _isRecording = false);
      
      try {
        final path = await _audioRecorder.stop();
        // Immediately resume playback as requested
        widget.onResumeRequested();

        if (path != null && path.isNotEmpty) {
          // Offload transcription to background task
          _processTranscription(path);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error stopping recorder: $e')),
          );
        }
      }
    } else {
      // Begin local audio recording
      widget.onPauseRequested();
      try {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
          _recordPath = '${dir.path}/VMemo_${DateTime.now().millisecondsSinceEpoch}.wav';
          
          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav, 
              numChannels: 1, 
              sampleRate: 16000
            ),
            path: _recordPath!,
          );
          
          setState(() => _isRecording = true);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Microphone permission denied.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start microphone: $e')),
          );
        }
      }
    }
  }

  Future<void> _processTranscription(String path) async {
    widget.onTranscriptionStart();
    try {
      final transcript = await LocalWhisperService.transcribe(path);
      if (transcript != null && transcript.trim().isNotEmpty) {
        await widget.onSaveNote(transcript.trim());
      }
    } catch (e) {
      debugPrint('Background transcription error: $e');
    } finally {
      widget.onTranscriptionEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    Color ringColor = _isRecording ? Colors.redAccent : kPrimaryColor;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.grey.shade100,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _handleTap,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ringColor,
                      boxShadow: [
                        BoxShadow(
                          color: ringColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isRecording
                        ? 'Recording... Tap to Finish'
                        : 'Tap to Record Note',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: ringColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (_isRecording) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Audiobook is paused',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
