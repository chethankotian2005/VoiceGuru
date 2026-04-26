import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalLibraryService {
  static final LocalLibraryService _instance = LocalLibraryService._internal();
  static Database? _database;

  factory LocalLibraryService() => _instance;

  LocalLibraryService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'voiceguru_library.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE library(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            question TEXT UNIQUE,
            explanation TEXT,
            subject TEXT,
            grade INTEGER,
            language TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
    );
  }

  Future<void> saveToLibrary({
    required String question,
    required String explanation,
    required String subject,
    required int grade,
    required String language,
  }) async {
    try {
      final db = await database;
      await db.insert(
        'library',
        {
          'question': question.toLowerCase().trim(),
          'explanation': explanation,
          'subject': subject,
          'grade': grade,
          'language': language,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error saving to library: $e');
    }
  }

  Future<Map<String, dynamic>?> searchLibrary(String query, String language) async {
    try {
      final db = await database;
      final normalizedQuery = query.toLowerCase().trim();
      
      // Try exact match first
      final List<Map<String, dynamic>> results = await db.query(
        'library',
        where: 'question = ? AND language = ?',
        whereArgs: [normalizedQuery, language],
        limit: 1,
      );

      if (results.isNotEmpty) return results.first;

      // Try fuzzy search if no exact match
      final List<Map<String, dynamic>> fuzzyResults = await db.query(
        'library',
        where: 'question LIKE ? AND language = ?',
        whereArgs: ['%$normalizedQuery%', language],
        limit: 1,
      );

      return fuzzyResults.isNotEmpty ? fuzzyResults.first : null;
    } catch (e) {
      print('Error searching library: $e');
      return null;
    }
  }
  
  Future<void> clearLibrary() async {
    final db = await database;
    await db.delete('library');
  }
}
