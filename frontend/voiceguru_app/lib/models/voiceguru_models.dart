import 'dart:convert';

class Suggestion {
  final String text;
  final String query;
  final String emoji;
  final String category;
  final String subject;

  Suggestion({
    required this.text,
    required this.query,
    required this.emoji,
    required this.category,
    required this.subject,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      text: _sanitizeForUi(json['text'] ?? ''),
      query: _sanitizeForUi(json['query'] ?? ''),
      emoji: json['emoji'] ?? '💡',
      category: json['category'] ?? 'fun',
      subject: json['subject'] ?? 'fun',
    );
  }
}
String _sanitizeForUi(String input) {
  final codeUnits = input.codeUnits;
  final out = StringBuffer();

  for (var i = 0; i < codeUnits.length; i++) {
    final cu = codeUnits[i];
    if (cu >= 0xD800 && cu <= 0xDBFF) {
      if (i + 1 < codeUnits.length) {
        final next = codeUnits[i + 1];
        if (next >= 0xDC00 && next <= 0xDFFF) {
          out.writeCharCode(cu);
          out.writeCharCode(next);
          i++;
          continue;
        }
      }
      out.write('\uFFFD');
      continue;
    }
    if (cu >= 0xDC00 && cu <= 0xDFFF) {
      out.write('\uFFFD');
      continue;
    }
    out.writeCharCode(cu);
  }

  return out.toString();
}

class VoiceGuruAnswer {
  VoiceGuruAnswer({
    required this.explanation,
    required this.subject,
    required this.gradeUsed,
    required this.language,
    required this.complexity,
    required this.agentTrace,
    this.needsDiagram = false,
    this.diagramDescription,
    this.diagramType = 'none',
    this.youtubeSearchQuery,
    this.keyTerms = const <String>[],
  });

  final String explanation;
  final String subject;
  final int gradeUsed;
  final String language;
  final String complexity;
  final List<String> agentTrace;
  final bool needsDiagram;
  final String? diagramDescription;
  final String diagramType;
  final String? youtubeSearchQuery;
  final List<String> keyTerms;

  factory VoiceGuruAnswer.fromJson(Map<String, dynamic> json) {
    return VoiceGuruAnswer(
      explanation: _sanitizeForUi(json['explanation']?.toString() ?? ''),
      subject: _sanitizeForUi(json['subject']?.toString() ?? 'General'),
      gradeUsed: _asInt(json['grade_used']) ?? 6,
      language: _sanitizeForUi(json['language']?.toString() ?? 'english'),
      complexity: _sanitizeForUi(json['complexity']?.toString() ?? 'medium'),
      agentTrace: (json['agent_trace'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toList() ??
          const <String>[],
      needsDiagram: json['needs_diagram'] == true,
        diagramDescription: json['diagram_description'] == null
          ? null
          : _sanitizeForUi(json['diagram_description'].toString()),
        diagramType: _sanitizeForUi(json['diagram_type']?.toString() ?? 'none'),
        youtubeSearchQuery: json['youtube_search_query'] == null
          ? null
          : _sanitizeForUi(json['youtube_search_query'].toString()),
      keyTerms: (json['key_terms'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toList() ??
          const <String>[],
    );
  }
}

class VoiceGuruHistoryEntry {
  VoiceGuruHistoryEntry({
    required this.question,
    required this.explanation,
    required this.subject,
    required this.grade,
    required this.language,
    required this.timestamp,
  });

  final String question;
  final String explanation;
  final String subject;
  final int grade;
  final String language;
  final DateTime? timestamp;

  factory VoiceGuruHistoryEntry.fromJson(Map<String, dynamic> json) {
    return VoiceGuruHistoryEntry(
      question: _sanitizeForUi(json['question']?.toString() ?? ''),
      explanation: _sanitizeForUi(json['explanation']?.toString() ?? ''),
      subject: _sanitizeForUi(json['subject']?.toString() ?? 'General'),
      grade: _asInt(json['grade']) ?? 0,
      language: _sanitizeForUi(json['language']?.toString() ?? 'english'),
      timestamp: _parseTimestamp(json['timestamp']),
    );
  }

  String get formattedDate {
    final value = timestamp;
    if (value == null) {
      return 'Recently';
    }

    final local = value.toLocal();
    final month = _months[local.month - 1];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day} $month ${local.year}, $hour:$minute $suffix';
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String prettyJson(Map<String, dynamic> json) =>
    const JsonEncoder.withIndent('  ').convert(json);

// ─── Progress Models ───

class WeeklyData {
  final String day;
  final int questions;
  final String date;

  WeeklyData({
    required this.day,
    required this.questions,
    required this.date,
  });

  factory WeeklyData.fromJson(Map<String, dynamic> json) {
    return WeeklyData(
      day: json['day']?.toString() ?? '',
      questions: _asInt(json['questions']) ?? 0,
      date: json['date']?.toString() ?? '',
    );
  }
}

class MonthlyData {
  final String week;
  final int questions;

  MonthlyData({required this.week, required this.questions});

  factory MonthlyData.fromJson(Map<String, dynamic> json) {
    return MonthlyData(
      week: json['week']?.toString() ?? '',
      questions: _asInt(json['questions']) ?? 0,
    );
  }
}

class ProgressData {
  final int streakDays;
  final int totalQuestions;
  final int todayQuestions;
  final int dailyGoal;
  final List<WeeklyData> weeklyData;
  final List<MonthlyData> monthlyData;
  final Map<String, int> subjectBreakdown;
  final List<String> badges;

  ProgressData({
    required this.streakDays,
    required this.totalQuestions,
    required this.todayQuestions,
    required this.dailyGoal,
    required this.weeklyData,
    required this.monthlyData,
    required this.subjectBreakdown,
    required this.badges,
  });

  factory ProgressData.empty() {
    final now = DateTime.now();
    return ProgressData(
      streakDays: 0,
      totalQuestions: 0,
      todayQuestions: 0,
      dailyGoal: 5,
      weeklyData: List.generate(7, (i) {
        final d = now.subtract(Duration(days: 6 - i));
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return WeeklyData(
          day: days[d.weekday - 1],
          questions: 0,
          date: d.toIso8601String().substring(0, 10),
        );
      }),
      monthlyData: List.generate(
          4, (i) => MonthlyData(week: 'Week ${i + 1}', questions: 0)),
      subjectBreakdown: {
        'math': 0,
        'science': 0,
        'social_studies': 0,
        'other': 0,
      },
      badges: [],
    );
  }

  factory ProgressData.fromJson(Map<String, dynamic> json) {
    final weeklyRaw = json['weekly_data'] as List<dynamic>? ?? [];
    final monthlyRaw = json['monthly_data'] as List<dynamic>? ?? [];
    final subjectRaw =
        (json['subject_breakdown'] as Map<String, dynamic>?) ?? {};
    final badgesRaw = (json['badges'] as List<dynamic>?) ?? [];

    return ProgressData(
      streakDays: _asInt(json['streak_days']) ?? 0,
      totalQuestions: _asInt(json['total_questions']) ?? 0,
      todayQuestions: _asInt(json['today_questions']) ?? 0,
      dailyGoal: _asInt(json['daily_goal']) ?? 5,
      weeklyData: weeklyRaw
          .whereType<Map<String, dynamic>>()
          .map(WeeklyData.fromJson)
          .toList(),
      monthlyData: monthlyRaw
          .whereType<Map<String, dynamic>>()
          .map(MonthlyData.fromJson)
          .toList(),
      subjectBreakdown:
          subjectRaw.map((k, v) => MapEntry(k, _asInt(v) ?? 0)),
      badges: badgesRaw.map((e) => e.toString()).toList(),
    );
  }
}
