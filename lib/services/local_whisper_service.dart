import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';

class LocalWhisperService {
  static Whisper? _whisper;
  static String? _modelPath;
  
  /// Initialize by making sure the Whisper model exists in a real path
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelFile = File('${dir.path}/ggml-tiny.en.bin');
    
    if (!await modelFile.exists()) {
      final byteData = await rootBundle.load('assets/models/ggml-tiny.en.bin');
      await modelFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    }
    
    _modelPath = modelFile.path;
    _whisper = Whisper(
      model: WhisperModel.tiny,
    );
  }
  
  /// Transcribe a 16kHz PCM WAV file natively chunking as needed
  static Future<String?> transcribe(String pcm16WavPath) async {
    if (_whisper == null || _modelPath == null) await init();
    final response = await _whisper!.transcribe(
      transcribeRequest: TranscribeRequest(audio: pcm16WavPath, language: 'en'),
      modelPath: _modelPath!,
    );
    return response.text;
  }
}

