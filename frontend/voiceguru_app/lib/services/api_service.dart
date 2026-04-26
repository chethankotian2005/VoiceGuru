import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_library_service.dart';

const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://voiceguru-backend.onrender.com',
);

class ApiService {
  ApiService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  // ─── Create User ───
  Future<Map<String, dynamic>?> createUser({
    required String childId,
    required String name,
    required int grade,
    required String board,
    required String language,
    required String mascot,
  }) async {
    try {
      final response = await _client.post(
        _uri('/create_user'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(
          <String, dynamic>{
            'child_id': childId,
            'name': name,
            'grade': grade,
            'board': board,
            'language': language,
            'mascot': mascot,
          },
        ),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ─── Ask question ───
  Future<Map<String, dynamic>> askQuestion({
    required String text,
    required String language,
    required int grade,
    required String childId,
    required String board,
  }) async {
    final online = await isOnline();
    if (!online) {
      return await _askOffline(text, language, grade);
    }

    try {
      final response = await _client.post(
        _uri('/ask'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(
          <String, dynamic>{
            'text': text,
            'language': language,
            'grade': grade,
            'child_id': childId,
            'board': board,
          },
        ),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (jsonDecode(response.body) as Map).cast<String, dynamic>();
      }
    } catch (_) {
      // Fall through to default response.
    }

    return <String, dynamic>{
      'explanation': 'I could not reach the server. Please try again.',
      'subject': 'General',
      'grade_used': grade,
      'language': language,
      'agent_trace': <String>['Client'],
      'needs_diagram': false,
      'diagram_description': null,
      'diagram_type': 'none',
      'youtube_search_query': null,
      'key_terms': <String>[],
    };
  }

  Future<Map<String, dynamic>> _askOffline(
    String text,
    String language,
    int grade,
  ) async {
    try {
      // 1. Try to find in Personal Smart Library
      final library = LocalLibraryService();
      final savedAnswer = await library.searchLibrary(text, language);
      
      if (savedAnswer != null) {
        return {
          'explanation': savedAnswer['explanation'],
          'subject': savedAnswer['subject'],
          'grade_used': savedAnswer['grade'],
          'language': savedAnswer['language'],
          'needs_diagram': false,
          'diagram_type': 'none',
          'youtube_search_query': null,
          'offline_mode': true,
          'is_from_library': true,
          'agent_trace': ['Personal Smart Library'],
        };
      }

      // 2. Fallback to generic offline message
      final cachedContext = _getCachedSyllabus(grade);
      final prompt = """You are VoiceGuru, an offline AI tutor. The student has no internet right now.
Answer this question briefly in $language:
$text

Context: $cachedContext

Keep answer under 80 words. Be warm and helpful.""";

      // For demo: simulation of a local AI response
      final response = await _getLocalResponse(prompt, language);
      return {
        'explanation': response,
        'subject': 'general',
        'grade_used': grade,
        'language': language,
        'needs_diagram': false,
        'diagram_type': 'none',
        'youtube_search_query': null,
        'offline_mode': true,
        'agent_trace': ['Offline AI'],
      };
    } catch (e) {
      return {
        'explanation': _getOfflineFallbackMessage(language),
        'offline_mode': true,
        'agent_trace': ['Offline Fallback'],
      };
    }
  }

  Future<String> _getLocalResponse(String prompt, String language) async {
    // This would eventually call Gemini Nano. 
    // For now, we simulate a warm offline response.
    await Future.delayed(const Duration(milliseconds: 800));
    return _getOfflineFallbackMessage(language);
  }

  String _getOfflineFallbackMessage(String language) {
    final messages = {
      'kannada': 'ನೀವು ಈಗ ಆಫ್ಲೈನ್ ಆಗಿದ್ದೀರಿ. ಆದರೆ ನಾನು ಇನ್ನೂ ಸಹಾಯ ಮಾಡಬಲ್ಲೆ!',
      'hindi': 'आप अभी ऑफलाइन हैं, लेकिन मैं अभी भी मदद कर सकता हूं!',
      'tamil': 'நீங்கள் இப்போது ஆஃப்லைனில் உள்ளீர்கள். ಆದರೆ ನಾನು உதவ முடியும்!',
      'english': 'You are offline right now, but I can still help with basic questions!',
    };
    return messages[language] ?? messages['english']!;
  }

  String _getCachedSyllabus(int grade) {
    return 'Karnataka State Board Class $grade curriculum topics';
  }

  // ─── Ask Image ───
  Future<Map<String, dynamic>> askImage({
    required String imageBase64,
    required String language,
    required int grade,
    required String childId,
    required String board,
    String? additionalContext,
  }) async {
    try {
      final response = await _client.post(
        _uri('/ask_image'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(
          <String, dynamic>{
            'image_base64': imageBase64,
            'language': language,
            'grade': grade,
            'child_id': childId,
            'board': board,
            if (additionalContext != null) 'additional_context': additionalContext,
          },
        ),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (jsonDecode(response.body) as Map).cast<String, dynamic>();
      }
    } catch (_) {}

    return <String, dynamic>{
      'explanation': 'I could not reach the server to analyze the image. Please try again.',
      'subject': 'General',
      'grade_used': grade,
      'language': language,
      'agent_trace': <String>['Client'],
      'needs_diagram': false,
      'diagram_description': null,
      'diagram_type': 'none',
      'youtube_search_query': null,
      'key_terms': <String>[],
    };
  }

  // ─── Simplify ───
  Future<Map<String, dynamic>> simplify({
    required String originalQuestion,
    required String originalExplanation,
    required String language,
    required int grade,
    required String childId,
  }) async {
    try {
      final response = await _client.post(
        _uri('/simplify'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(
          <String, dynamic>{
            'original_question': originalQuestion,
            'original_explanation': originalExplanation,
            'language': language,
            'grade': grade,
            'child_id': childId,
          },
        ),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (jsonDecode(response.body) as Map).cast<String, dynamic>();
      }
    } catch (_) {
      // Fall through to default response.
    }

    return <String, dynamic>{
      'simplified_explanation':
          'I could not simplify this right now. Please try again.',
    };
  }

  // ─── Transcribe ───
  Future<Map<String, dynamic>> transcribe({
    required String audioBase64,
    required String language,
  }) async {
    try {
      final response = await _client.post(
        _uri('/transcribe'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(
          <String, dynamic>{
            'audio_base64': audioBase64,
            'language': language,
          },
        ),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (jsonDecode(response.body) as Map).cast<String, dynamic>();
      }
    } catch (_) {}

    return <String, dynamic>{
      'text': '',
      'is_hotword': false,
      'hotword_detected': null,
    };
  }

  // ─── YouTube search ───
  Future<List<Map<String, dynamic>>> youtubeSearch({
    required String query,
    required int grade,
    int maxResults = 3,
  }) async {
    try {
      final uri = _uri('/youtube_search').replace(
        queryParameters: <String, String>{
          'query': query,
          'grade': grade.toString(),
          'max_results': maxResults.toString(),
        },
      );

        final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 60));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>?;
        if (results != null) {
          return results
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
        }
      }
    } catch (_) {}

    return <Map<String, dynamic>>[];
  }

  // ─── History ───
  Future<List<dynamic>> getHistory(String childId) async {
    try {
        final response = await _client
          .get(_uri('/history/$childId'))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <dynamic>[];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is List<dynamic>) {
        return decoded;
      }
      if (decoded is Map<String, dynamic> && decoded['history'] is List<dynamic>) {
        return decoded['history'] as List<dynamic>;
      }
    } catch (_) {
      return <dynamic>[];
    }

    return <dynamic>[];
  }

  // ─── Suggestions ───
  Future<List<Map<String, dynamic>>> getSuggestions({
    required int grade,
    required String language,
    String? subject,
  }) async {
    try {
      final subjectQuery = subject != null ? '&subject=${Uri.encodeComponent(subject)}' : '';
      final response = await _client
          .get(_uri('/suggestions?grade=$grade&language=${Uri.encodeComponent(language)}$subjectQuery'))
          .timeout(const Duration(seconds: 15));
          
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded.containsKey('suggestions')) {
          return List<Map<String, dynamic>>.from(decoded['suggestions']);
        }
      }
    } catch (_) {
      // Fall through on error
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _emptyProgress() => {
    'streak_days': 0,
    'total_questions': 0,
    'today_questions': 0,
    'daily_goal': 5,
    'weekly_data': List.generate(7, (i) => 
      {'questions': 0, 'day': ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][i], 'date': ''}
    ),
    'monthly_data': <dynamic>[],
    'subject_breakdown': <String, dynamic>{},
    'badges': <dynamic>[],
  };

  Future<Map<String, dynamic>> getProgress(String childId) async {
    try {
      final response = await _client
          .get(_uri('/progress/$childId'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (jsonDecode(response.body) as Map).cast<String, dynamic>();
      }
      return _emptyProgress();
    } catch (_) {
      return _emptyProgress();
    }
  }

  // ─── Quiz ───
  Future<Map<String, dynamic>> generateQuiz({
    required String childId,
    required int grade,
    required String language,
    int numQuestions = 5,
  }) async {
    try {
      final response = await _client.post(
        _uri('/generate_quiz'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'child_id': childId,
          'grade': grade,
          'language': language,
          'num_questions': numQuestions,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (jsonDecode(response.body) as Map).cast<String, dynamic>();
      }
    } catch (_) {}
    return <String, dynamic>{'questions': [], 'topics': [], 'num_questions': 0};
  }

  Future<Map<String, dynamic>> submitQuiz({
    required String childId,
    required List<Map<String, dynamic>> answers,
    required int grade,
    required String language,
  }) async {
    try {
      final response = await _client.post(
        _uri('/submit_quiz'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'child_id': childId,
          'answers': answers,
          'grade': grade,
          'language': language,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (jsonDecode(response.body) as Map).cast<String, dynamic>();
      }
    } catch (_) {}
    return <String, dynamic>{
      'score': 0, 'total': 0, 'percentage': 0,
      'results': [], 'badge_earned': null, 'stars_earned': 0,
    };
  }

  void dispose() {
    _client.close();
  }
}
