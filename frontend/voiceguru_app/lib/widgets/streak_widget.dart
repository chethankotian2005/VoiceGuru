import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import '../l10n/app_strings.dart';
import '../models/progress_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DUOLINGO-STYLE STREAK BANNER
// ─────────────────────────────────────────────────────────────────────────────
class StreakBanner extends StatelessWidget {
  const StreakBanner({
    super.key,
    required this.streak,
    required this.todayQuestions,
    required this.dailyGoal,
    required this.lang,
    this.onTap,
  });

  final int streak;
  final int todayQuestions;
  final int dailyGoal;
  final String lang;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasStreak = streak > 0;
    final int clampedToday = todayQuestions.clamp(0, dailyGoal);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: hasStreak
                ? const [Color(0xFFFF9600), Color(0xFFFF6B00)]
                : const [Color(0xFFE0E0E0), Color(0xFFBDBDBD)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: hasStreak
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF9600).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // ── Animated flame or sleep icon ──
            if (hasStreak)
              const Text('🔥', style: TextStyle(fontSize: 28))
                  .animate(onPlay: (c) => c.repeat())
                  .scaleXY(
                    begin: 1.0,
                    end: 1.15,
                    duration: 800.ms,
                    curve: Curves.easeInOut,
                  )
                  .then()
                  .scaleXY(begin: 1.15, end: 1.0, duration: 800.ms)
            else
              const Text('💤', style: TextStyle(fontSize: 24)),

            const SizedBox(width: 10),

            // ── Streak text + today count ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasStreak
                      ? '$streak ${AppStrings.get("day_streak", lang)}'
                      : 'Start your streak today!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '$clampedToday/$dailyGoal ${AppStrings.get("today", lang)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ── Duolingo-style dot progress ──
            Row(
              children: List.generate(dailyGoal.clamp(0, 5), (i) {
                final filled = i < clampedToday;
                return Container(
                  margin: const EdgeInsets.only(left: 4),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    border: filled
                        ? null
                        : Border.all(
                            color: Colors.white.withOpacity(0.5), width: 1),
                  ),
                )
                    .animate(delay: Duration(milliseconds: i * 80))
                    .scale(duration: 200.ms);
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STREAK MILESTONE CELEBRATION OVERLAY
// ─────────────────────────────────────────────────────────────────────────────
class StreakCelebrationOverlay extends StatefulWidget {
  const StreakCelebrationOverlay({
    super.key,
    required this.streak,
    required this.onDismiss,
  });

  final int streak;
  final VoidCallback onDismiss;

  @override
  State<StreakCelebrationOverlay> createState() =>
      _StreakCelebrationOverlayState();
}

class _StreakCelebrationOverlayState extends State<StreakCelebrationOverlay> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _confetti.play();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dim background
        GestureDetector(
          onTap: widget.onDismiss,
          child: Container(color: Colors.black45),
        ),
        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 40,
            gravity: 0.3,
            colors: const [
              Colors.orange,
              Colors.yellow,
              Colors.blue,
              Colors.green,
              Colors.pink,
            ],
          ),
        ),
        // Center card
        Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(blurRadius: 20, color: Colors.black26),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 72))
                    .animate()
                    .scale(
                        duration: 600.ms, curve: Curves.elasticOut),
                const SizedBox(height: 12),
                Text(
                  '${widget.streak} Day Streak!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B00),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "You're on fire! Keep going!",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),
                // Progress dots for daily goal met
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF9600),
                    ),
                  ).animate(delay: Duration(milliseconds: i * 100))
                    .scale(duration: 300.ms, curve: Curves.elasticOut)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  7-DAY STREAK CALENDAR  (Duolingo style)
// ─────────────────────────────────────────────────────────────────────────────
class StreakCalendar extends StatelessWidget {
  const StreakCalendar({
    super.key,
    required this.weeklyData,
    required this.lang,
  });

  final List<WeeklyData> weeklyData;
  final String lang;

  static const Map<String, List<String>> _dayLetters = {
    'english': ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
    'kannada': ['ಭ', 'ಸೋ', 'ಮ', 'ಬು', 'ಗು', 'ಶು', 'ಶ'],
    'hindi':   ['र', 'सो', 'म', 'बु', 'गु', 'शु', 'श'],
    'tamil':   ['ஞ', 'தி', 'செ', 'பு', 'வி', 'வெ', 'ச'],
  };

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final labels = _dayLetters[lang] ?? _dayLetters['english']!;

    // Build a map of date string → question count from weeklyData
    final Map<String, int> questionsByDate = {
      for (final wd in weeklyData) wd.date: wd.questions,
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Streak Calendar',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF202124),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              // i=0 is 6 days ago, i=6 is today
              final day = today.subtract(Duration(days: 6 - i));
              final dateStr = day.toIso8601String().substring(0, 10);
              final count = questionsByDate[dateStr] ?? 0;
              final isToday = i == 6;
              final hasActivity = count > 0;

              // Day letter: use weekday (1=Mon..7=Sun), map to Sun=0..Sat=6
              final weekdayIndex = (day.weekday % 7); // Sun=0,Mon=1..Sat=6
              final letter = weekdayIndex < labels.length
                  ? labels[weekdayIndex]
                  : '?';

              return _DayCircle(
                letter: letter,
                hasActivity: hasActivity,
                isToday: isToday,
                index: i,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({
    required this.letter,
    required this.hasActivity,
    required this.isToday,
    required this.index,
  });

  final String letter;
  final bool hasActivity;
  final bool isToday;
  final int index;

  @override
  Widget build(BuildContext context) {
    Widget circle;

    if (hasActivity) {
      // ── Active: filled orange gradient with white checkmark ──
      circle = Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFFF9600), Color(0xFFFF6B00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x66FF9600),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '✓',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ).animate(delay: Duration(milliseconds: index * 60))
       .scale(duration: 300.ms, curve: Curves.elasticOut);
    } else if (isToday) {
      // ── Today, no activity yet: pulsing outlined circle with flame ──
      circle = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(
            color: const Color(0xFFFF9600),
            width: 2.5,
          ),
        ),
        child: const Center(
          child: Text('🔥', style: TextStyle(fontSize: 16)),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
              begin: 1.0, end: 1.12, duration: 900.ms, curve: Curves.easeInOut);
    } else {
      // ── Past missed day: gray circle ──
      circle = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle,
        const SizedBox(height: 6),
        Text(
          letter,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            color: isToday
                ? const Color(0xFFFF6B00)
                : hasActivity
                    ? const Color(0xFFFF9600)
                    : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}
