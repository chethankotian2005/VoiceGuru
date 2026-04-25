import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'api_service.dart';

/// Continuously listens via the microphone, sends 3-second chunks
/// to POST /transcribe, and fires callbacks for hotword or question.
class HotwordService {
  HotwordService({
    required this.apiService,
    required this.language,
    this.onHotwordDetected,
    this.onQuestionDetected,
    this.onError,
  });

  final ApiService apiService;
  final String language;
  final void Function()? onHotwordDetected;
  final void Function(String text)? onQuestionDetected;
  final void Function(String error)? onError;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _subscription;
  Timer? _chunkTimer;
  final List<int> _buffer = <int>[];
  bool _listening = false;

  bool get isListening => _listening;

  Future<void> startListening() async {
    if (_listening) return;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        onError?.call('Microphone permission denied');
        return;
      }

      _listening = true;
      _buffer.clear();

      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      final stream = await _recorder.startStream(config);
      _subscription = stream.listen(
        (Uint8List chunk) {
          _buffer.addAll(chunk);
        },
        onError: (e) {
          onError?.call(e.toString());
        },
      );

      // Process every 3 seconds
      _chunkTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _processChunk(),
      );
    } catch (e) {
      _listening = false;
      onError?.call(e.toString());
    }
  }

  Future<void> _processChunk() async {
    if (_buffer.isEmpty) return;

    final audioBytes = Uint8List.fromList(_buffer);
    _buffer.clear();

    try {
      final result = await apiService.transcribe(
        audioBase64: base64Encode(audioBytes),
        language: language,
      );

      final isHotword = result['is_hotword'] == true;
      final text = (result['text'] ?? '').toString().trim();

      if (isHotword) {
        onHotwordDetected?.call();
      } else if (text.isNotEmpty && text.length > 3) {
        // Filter out noise — only trigger if there's meaningful text
        onQuestionDetected?.call(text);
      }
    } catch (e) {
      onError?.call(e.toString());
    }
  }

  Future<void> stopListening() async {
    _listening = false;
    _chunkTimer?.cancel();
    _chunkTimer = null;

    await _subscription?.cancel();
    _subscription = null;

    try {
      await _recorder.stop();
    } catch (_) {}

    _buffer.clear();
  }

  Future<void> dispose() async {
    await stopListening();
    try {
      await _recorder.dispose();
    } catch (_) {}
  }
}
