import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/progress_data.dart';

class StreakProvider extends ChangeNotifier {
  ProgressData _progress = ProgressData.empty();
  bool _isLoading = false;
  bool _streakJustIncreased = false;
  bool _levelJustIncreased = false;
  bool _goalJustMet = false;

  ProgressData get progress => _progress;
  bool get isLoading => _isLoading;
  bool get streakJustIncreased => _streakJustIncreased;
  bool get levelJustIncreased => _levelJustIncreased;
  bool get goalJustMet => _goalJustMet;

  int get level {
    final tq = _progress.totalQuestions;
    if (tq >= 100) return 5;
    if (tq >= 50) return 4;
    if (tq >= 25) return 3;
    if (tq >= 10) return 2;
    return 1;
  }

  void clearJustIncreasedFlags() {
    _streakJustIncreased = false;
    _levelJustIncreased = false;
    _goalJustMet = false;
  }

  Future<void> fetchProgress(String childId, String backendBaseUrl) async {
    _isLoading = true;
    notifyListeners();

    try {
      final uri = Uri.parse('$backendBaseUrl/progress/$childId');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw =
            (jsonDecode(response.body) as Map).cast<String, dynamic>();
        if (raw.isNotEmpty) {
          final previousStreak = _progress.streakDays;
          final previousLevel = level;
          final previousToday = _progress.todayQuestions;
          final previousGoal = _progress.dailyGoal;

          _progress = ProgressData.fromJson(raw);

          if (_progress.streakDays > previousStreak) {
            _streakJustIncreased = true;
          }
          if (level > previousLevel) {
            _levelJustIncreased = true;
          }
          // Goal just met: crossed the threshold this fetch
          if (previousToday < previousGoal &&
              _progress.todayQuestions >= _progress.dailyGoal) {
            _goalJustMet = true;
          }
        }
      }
    } catch (_) {
      // keep stale data on error
    }

    _isLoading = false;
    notifyListeners();
  }
}
