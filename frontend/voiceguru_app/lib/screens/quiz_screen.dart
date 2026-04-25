import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/api_service.dart';
import '../l10n/app_strings.dart';
import '../providers/language_provider.dart';

// ─────────────────────────────────────────────
//  Quiz Screen — 3-state: Intro → Active → Results
// ─────────────────────────────────────────────
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.grade,
    required this.language,
    required this.childId,
    required this.backendBaseUrl,
  });

  final int grade;
  final String language;
  final String childId;
  final String backendBaseUrl;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

enum _QuizPhase { intro, active, results }

class _QuizScreenState extends State<QuizScreen> {
  late final ApiService _api;
  late final ConfettiController _confettiController;

  _QuizPhase _phase = _QuizPhase.intro;
  bool _isLoading = true;

  // Quiz data from backend
  List<dynamic> _questions = [];
  List<String> _topics = [];

  // Active quiz state
  int _currentIndex = 0;
  String? _selectedOption;
  bool _submitted = false;
  int _secondsLeft = 30;
  Timer? _timer;

  // Answers collected
  final List<Map<String, dynamic>> _answers = [];

  // Results
  Map<String, dynamic> _resultData = {};

  @override
  void initState() {
    super.initState();
    _api = ApiService(baseUrl: widget.backendBaseUrl);
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _loadQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final result = await _api.generateQuiz(
      childId: context.read<LanguageProvider>().childId,
      grade: widget.grade,
      language: widget.language,
    );

    if (!mounted) return;
    setState(() {
      _questions = (result['questions'] as List<dynamic>?) ?? [];
      _topics = ((result['topics'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList();
      _isLoading = false;
    });
  }

  void _startQuiz() {
    setState(() {
      _phase = _QuizPhase.active;
      _currentIndex = 0;
      _selectedOption = null;
      _submitted = false;
      _answers.clear();
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          timer.cancel();
          if (!_submitted) _submitAnswer();
        }
      });
    });
  }

  void _submitAnswer() {
    _timer?.cancel();
    _answers.add({
      'question_index': _currentIndex,
      'selected': _selectedOption ?? '',
    });
    setState(() => _submitted = true);
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _submitted = false;
      });
      _startTimer();
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _isLoading = true);

    final result = await _api.submitQuiz(
      childId: context.read<LanguageProvider>().childId,
      answers: _answers,
      grade: widget.grade,
      language: widget.language,
    );

    if (!mounted) return;
    setState(() {
      _resultData = result;
      _phase = _QuizPhase.results;
      _isLoading = false;
    });

    final pct = (result['percentage'] as num?) ?? 0;
    if (pct >= 80) {
      _confettiController.play();
    }
  }

  void _tryAgain() {
    setState(() {
      _phase = _QuizPhase.intro;
      _questions = [];
      _topics = [];
      _answers.clear();
      _resultData = {};
    });
    _loadQuiz();
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().language;
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(AppStrings.get('daily_quiz', lang)),
        backgroundColor: kSurface,
        elevation: 0,
        foregroundColor: kTextPrimary,
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: kGoogleBlue),
            )
          else
            switch (_phase) {
              _QuizPhase.intro => _buildIntro(lang),
              _QuizPhase.active => _buildActiveQuiz(lang),
              _QuizPhase.results => _buildResults(lang),
            },
          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 30,
              gravity: 0.2,
              colors: const [
                kGoogleBlue,
                kGoogleRed,
                kGoogleYellow,
                kGoogleGreen,
                Colors.purple,
                Colors.orange,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── INTRO ───
  Widget _buildIntro(String lang) {
    final hasTopics = _topics.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Text('📝', style: TextStyle(fontSize: 72))
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1)),
          const SizedBox(height: 24),
          Text(
            AppStrings.get('daily_quiz', lang),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            hasTopics
                ? AppStrings.get('based_on_today', lang)
                : "Let's test general knowledge!",
            style: TextStyle(fontSize: 16, color: kTextSecondary),
          ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
          const SizedBox(height: 24),
          // Topic chips
          if (_topics.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _topics
                  .map((t) => Chip(
                        label: Text(t, style: const TextStyle(fontSize: 13)),
                        backgroundColor: kGoogleBlue.withValues(alpha: 0.1),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ))
                  .toList(),
            ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
          const SizedBox(height: 16),
          // Info cards
          _infoTile(Icons.quiz_outlined, AppStrings.get('questions_label', lang)),
          _infoTile(Icons.timer_outlined, AppStrings.get('time_per_q', lang)),
          _infoTile(Icons.star_outline_rounded, AppStrings.get('earn_stars', lang)),
          const SizedBox(height: 32),
          // Start button
          if (_questions.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _startQuiz,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGoogleBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  AppStrings.get('start_quiz', lang),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ).animate().fadeIn(delay: 450.ms, duration: 400.ms).slideY(begin: 0.2)
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Could not generate quiz questions. Try again later.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: kGoogleBlue),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 15, color: kTextSecondary)),
        ],
      ),
    );
  }

  // ─── ACTIVE QUIZ ───
  Widget _buildActiveQuiz(String lang) {
    if (_currentIndex >= _questions.length) {
      return const Center(child: CircularProgressIndicator());
    }
    final q = _questions[_currentIndex] as Map<String, dynamic>;
    final questionText = q['question']?.toString() ?? '';
    final options = (q['options'] as List<dynamic>?) ?? [];
    final correctLetter = q['correct']?.toString().toUpperCase() ?? '';
    final explanation = q['explanation']?.toString() ?? '';
    final timerFraction = _secondsLeft / 30.0;
    final timerColor = _secondsLeft <= 10 ? kGoogleRed : kGoogleBlue;

    return Column(
      children: [
        // Progress bar
        Container(
          color: kSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                'Question ${_currentIndex + 1}/${_questions.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              // Circular timer
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60, height: 60,
                    child: CircularProgressIndicator(
                      value: _secondsLeft / 30,
                      strokeWidth: 5,
                      backgroundColor: Colors.grey.shade200,
                      color: _secondsLeft > 10 
                        ? const Color(0xFF34A853)  // green
                        : _secondsLeft > 5 
                          ? const Color(0xFFFBBC05)  // yellow
                          : const Color(0xFFEA4335), // red
                    ),
                  ),
                  Text(
                    '$_secondsLeft',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: _secondsLeft <= 5 
                        ? const Color(0xFFEA4335) 
                        : Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Linear progress
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions.length,
          backgroundColor: Colors.grey.shade200,
          color: kGoogleBlue,
          minHeight: 4,
        ),
        // Question + options
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  questionText,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                    height: 1.4,
                  ),
                ).animate().fadeIn(duration: 300.ms),
                const SizedBox(height: 24),
                // Options
                ...List.generate(options.length, (i) {
                  final optionText = options[i].toString();
                  final letter = String.fromCharCode(65 + i); // A, B, C, D
                  final isSelected = _selectedOption == letter;

                  Color bgColor = Colors.white;
                  Color borderColor = kGoogleBlue.withValues(alpha: 0.3);
                  IconData? trailingIcon;
                  Color? trailingColor;

                  if (_submitted) {
                    if (letter == correctLetter) {
                      bgColor = Colors.green.shade50;
                      borderColor = Colors.green;
                      trailingIcon = Icons.check_circle;
                      trailingColor = Colors.green;
                    } else if (isSelected && letter != correctLetter) {
                      bgColor = Colors.red.shade50;
                      borderColor = Colors.red;
                      trailingIcon = Icons.cancel;
                      trailingColor = Colors.red;
                    }
                  } else if (isSelected) {
                    bgColor = kGoogleBlue.withValues(alpha: 0.08);
                    borderColor = kGoogleBlue;
                  }

                  return GestureDetector(
                    onTap: _submitted ? null : () => setState(() => _selectedOption = letter),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor, width: 2),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              optionText,
                              style: TextStyle(
                                fontSize: 16,
                                color: kTextPrimary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (trailingIcon != null)
                            Icon(trailingIcon, color: trailingColor, size: 24),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: Duration(milliseconds: 100 + i * 80), duration: 300.ms);
                }),
                // Explanation after submit
                if (_submitted) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            explanation,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.amber.shade900,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),
                ],
              ],
            ),
          ),
        ),
        // Bottom button
        Container(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
          decoration: BoxDecoration(
            color: kSurface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitted
                  ? _nextQuestion
                  : (_selectedOption != null ? _submitAnswer : null),
              style: ElevatedButton.styleFrom(
                backgroundColor: _submitted ? kGoogleGreen : kGoogleBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                _submitted
                    ? (_currentIndex < _questions.length - 1
                        ? AppStrings.get('next_question', lang)
                        : AppStrings.get('see_results', lang))
                    : AppStrings.get('submit_answer', lang),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── RESULTS ───
  Widget _buildResults(String lang) {
    final score = (_resultData['score'] as num?) ?? 0;
    final total = (_resultData['total'] as num?) ?? 0;
    final percentage = (_resultData['percentage'] as num?) ?? 0;
    final starsEarned = (_resultData['stars_earned'] as num?) ?? 0;
    final badge = _resultData['badge_earned']?.toString();
    final results = (_resultData['results'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final filled = i < starsEarned.toInt();
              return Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 52,
                color: filled ? Colors.amber : Colors.grey.shade300,
              )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 200 + i * 150))
                  .scale(
                    begin: const Offset(0.3, 0.3),
                    end: const Offset(1, 1),
                    curve: Curves.elasticOut,
                    duration: 600.ms,
                  );
            }),
          ),
          const SizedBox(height: 24),
          // Score
          Text(
            '$score / $total',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: percentage >= 80
                  ? kGoogleGreen
                  : percentage >= 40
                      ? kGoogleYellow
                      : kGoogleRed,
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
          const SizedBox(height: 4),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 20,
              color: kTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Badge
          if (badge != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    badge.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
          ],
          const SizedBox(height: 32),
          // Review section
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppStrings.get('review', lang),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(results.length.clamp(0, _questions.length), (i) {
            final r = results[i] as Map<String, dynamic>;
            final isCorrect = r['correct'] == true;
            final q = i < _questions.length ? _questions[i] as Map<String, dynamic> : {};
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCorrect ? Colors.green.shade200 : Colors.red.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? Colors.green : Colors.red,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          q['question']?.toString() ?? 'Q${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${AppStrings.get('your_answer', lang)}: ${r['selected']}  •  ${AppStrings.get('correct', lang)}: ${r['correct_answer']}',
                    style: TextStyle(
                      fontSize: 13,
                      color: kTextSecondary,
                    ),
                  ),
                  if ((r['explanation']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      r['explanation'].toString(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: 100 * i), duration: 300.ms);
          }),
          const SizedBox(height: 24),
          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _tryAgain,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kGoogleBlue,
                    side: const BorderSide(color: kGoogleBlue, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(AppStrings.get('try_again', lang), style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGoogleBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(AppStrings.get('back_learning', lang),
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
