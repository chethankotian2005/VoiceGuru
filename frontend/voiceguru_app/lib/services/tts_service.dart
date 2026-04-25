import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class TtsService {
  final String baseUrl;
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  bool isPlaying = false;
  String? _lastTempFile;

  final Map<String, String> _ttsLanguageMap = {
    'kannada': 'kn-IN',
    'hindi': 'hi-IN',
    'tamil': 'ta-IN',
    'english': 'en-IN',
  };

  TtsService({required this.baseUrl});

  Future<void> initialize() async {
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.1);
    _flutterTts.setCompletionHandler(() {
      isPlaying = false;
    });
  }

  Future<void> speak(String text, String language) async {
    if (text.isEmpty) return;

    try {
      if (isPlaying) {
        await stop();
      }

      isPlaying = true;

      // Try backend Google TTS first (better quality)
      final uri = Uri.parse(
        '$baseUrl/speak?text=${Uri.encodeComponent(text)}&language=$language',
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final String audioBase64 = json['audio_base64'] ?? '';

        if (audioBase64.isNotEmpty) {
          final Uint8List audioBytes = base64Decode(audioBase64);
          if (audioBytes.isNotEmpty) {
            // Write to a temp file — most reliable approach on Android.
            await _cleanupTemp();
            final tempDir = await getTemporaryDirectory();
            final filePath =
                '${tempDir.path}/voiceguru_tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
            final file = File(filePath);
            await file.writeAsBytes(audioBytes, flush: true);
            _lastTempFile = filePath;

            await _player.setFilePath(filePath);
            _player.playerStateStream.listen((state) {
              if (state.processingState == ProcessingState.completed) {
                isPlaying = false;
              }
            });
            await _player.play();
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Backend TTS failed: $e, falling back to local flutter_tts');
    }

    // Fallback: on-device flutter_tts
    final langCode = _ttsLanguageMap[language] ?? 'en-IN';
    await _flutterTts.setLanguage(langCode);
    await _flutterTts.speak(text);
  }

  Future<void> _cleanupTemp() async {
    final path = _lastTempFile;
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    _lastTempFile = null;
  }

  Future<void> stop() async {
    isPlaying = false;
    await _player.stop();
    await _flutterTts.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _flutterTts.stop();
    await _cleanupTemp();
  }
}
