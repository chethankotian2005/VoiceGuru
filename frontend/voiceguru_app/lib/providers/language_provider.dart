import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _language = 'english';
  String _childName = '';
  String _childId = '';
  int _grade = 6;
  String _board = 'Karnataka State Board';
  String _mascot = 'owl';

  String get language => _language;
  String get childName => _childName;
  String get childId => _childId;
  int get grade => _grade;
  String get board => _board;
  String get mascot => _mascot;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Generate child_id if not exists
    _childId = prefs.getString('child_id') ?? '';
    if (_childId.isEmpty) {
      _childId = 'child_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('child_id', _childId);
    }

    _language = prefs.getString('language') ?? 'english';
    _childName = prefs.getString('child_name') ?? '';
    _grade = prefs.getInt('grade') ?? 6;
    _board = prefs.getString('board') ?? 'Karnataka State Board';
    _mascot = prefs.getString('mascot') ?? 'owl';
    notifyListeners();
  }

  Future<void> updateLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name, int? grade, 
    String? board, String? language,
    String? mascot,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      _childName = name;
      await prefs.setString('child_name', name);
    }
    if (grade != null) {
      _grade = grade;
      await prefs.setInt('grade', grade);
    }
    if (board != null) {
      _board = board;
      await prefs.setString('board', board);
    }
    if (language != null) {
      _language = language;
      await prefs.setString('language', language);
    }
    if (mascot != null) {
      _mascot = mascot;
      await prefs.setString('mascot', mascot);
    }
    notifyListeners();
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _language = 'english';
    _childName = '';
    _childId = '';
    _grade = 6;
    _board = 'Karnataka State Board';
    _mascot = 'owl';
    notifyListeners();
  }
}
