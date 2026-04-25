// lib/models/progress_data.dart
// Separate file to avoid stale-cache import resolution issues.

class WeeklyData {
  final String day;
  final int questions;
  final String date;

  WeeklyData({
    required this.day,
    required this.questions,
    required this.date,
  });

  factory WeeklyData.fromJson(Map<String, dynamic> json) => WeeklyData(
        day: json['day']?.toString() ?? '',
        questions: _asInt(json['questions']) ?? 0,
        date: json['date']?.toString() ?? '',
      );
}

class MonthlyData {
  final String week;
  final int questions;

  MonthlyData({required this.week, required this.questions});

  factory MonthlyData.fromJson(Map<String, dynamic> json) => MonthlyData(
        week: json['week']?.toString() ?? '',
        questions: _asInt(json['questions']) ?? 0,
      );
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
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return ProgressData(
      streakDays: 0,
      totalQuestions: 0,
      todayQuestions: 0,
      dailyGoal: 5,
      weeklyData: List.generate(7, (i) {
        final d = now.subtract(Duration(days: 6 - i));
        return WeeklyData(
          day: dayNames[d.weekday - 1],
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
    final weeklyRaw = (json['weekly_data'] as List<dynamic>?) ?? [];
    final monthlyRaw = (json['monthly_data'] as List<dynamic>?) ?? [];
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
      subjectBreakdown: subjectRaw.map((k, v) => MapEntry(k, _asInt(v) ?? 0)),
      badges: badgesRaw.map((e) => e.toString()).toList(),
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
