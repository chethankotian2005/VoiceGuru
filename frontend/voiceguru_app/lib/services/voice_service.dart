import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  String _currentLocale = 'en_IN';

  final Map<String, String> _localeMap = {
    'kannada': 'kn_IN',
    'hindi': 'hi_IN',
    'tamil': 'ta_IN',
    'english': 'en_IN',
  };

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) => debugPrint('STT error: $error'),
      onStatus: (status) => debugPrint('STT status: $status'),
    );
    return _isInitialized;
  }

  void setLanguage(String language) {
    _currentLocale = _localeMap[language.toLowerCase()] ?? 'en_IN';
  }

  void updateLocale(String language) {
    _currentLocale = _localeMap[language.toLowerCase()] ?? 'en_IN';
  }

  Future<void> startListening({
    required Function(String text) onResult,
    required Function() onListeningStarted,
    required Function() onListeningStopped,
  }) async {
    if (!_isInitialized) await initialize();
    if (!_isInitialized) return;

    onListeningStarted();

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          onResult(result.recognizedWords);
        }
      },
      localeId: _currentLocale,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: false,
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;

  void dispose() {
    _speech.cancel();
  }
}
