import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/local_whisper_service.dart';
import '../theme.dart';

/// Large-tap car mode UI for flawless native audio recording and Local Whisper.
class CarModePanel extends StatefulWidget {
  final Future<void> Function(String) onSaveNote;
  final VoidCallback onPauseRequested;

  const CarModePanel({
    super.key,
    required this.onSaveNote,
    required this.onPauseRequested,
  });

  @override
  State<CarModePanel> createState() => _CarModePanelState();
}

class _CarModePanelState extends State<CarModePanel> {
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isProcessing = false;
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
    if (_isProcessing) return;

    if (_isRecording) {
      // Stop recording and pass to local whisper
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      try {
        final path = await _audioRecorder.stop();
        if (path != null && path.isNotEmpty) {
          final transcript = await LocalWhisperService.transcribe(path);
          if (transcript != null && transcript.trim().isNotEmpty) {
            await widget.onSaveNote(transcript.trim());
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), duration: const Duration(seconds: 4)),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    } else {
      // Begin local audio recording
      widget.onPauseRequested();
      try {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
          // Provide a clean permanent filename instead of temp
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

  @override
  Widget build(BuildContext context) {
    Color ringColor = kPrimaryColor;
    if (_isRecording) ringColor = Colors.redAccent;
    if (_isProcessing) ringColor = Colors.orange;

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
                    child: _isProcessing
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Icon(
                            _isRecording ? Icons.stop : Icons.mic,
                            size: 60,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isProcessing
                        ? 'Transcribing Note Offline...'
                        : _isRecording
                            ? 'Recording... Tap to Stop'
                            : 'Tap to Record Note',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: ringColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (_isProcessing) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'Running Whisper local inference...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
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
