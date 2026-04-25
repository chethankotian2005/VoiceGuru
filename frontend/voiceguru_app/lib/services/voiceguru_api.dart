import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/voiceguru_models.dart';

class VoiceGuruApi {
  VoiceGuruApi({required this.baseUrl});

  final String baseUrl;

  Uri _uri(String path) {
    return Uri.parse('$baseUrl$path');
  }

  Future<VoiceGuruAnswer> askQuestion({
    required String childId,
    required String language,
    required int grade,
    required String audioBase64,
  }) async {
    try {
      final response = await http.post(
        _uri('/ask'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': 'Voice question from child',
          'language': language,
          'grade': grade,
          'child_id': childId,
          'audio_base64': audioBase64,
          'audio_format': 'pcm16',
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return VoiceGuruAnswer.fromJson(data);
      }
    } catch (_) {
      // Return fallback below.
    }

    return VoiceGuruAnswer(
      explanation:
          'I could not reach the learning server right now. Please try again in a moment.',
      subject: 'General',
      gradeUsed: grade,
      language: language,
      complexity: 'unknown',
      agentTrace: const <String>['Client'],
    );
  }

  Future<List<VoiceGuruHistoryEntry>> getHistory(String childId) async {
    try {
      final response = await http.get(_uri('/history/$childId'));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final rawItems = decoded is List ? decoded : const [];
        return rawItems
            .whereType<Map>()
            .map((item) => VoiceGuruHistoryEntry.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ))
            .toList();
      }
    } catch (_) {
      // Empty fallback below.
    }
    return <VoiceGuruHistoryEntry>[];
  }
}
