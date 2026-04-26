import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/progress_data.dart';
import '../providers/streak_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../widgets/streak_widget.dart';

// ─────────────────────────────────────────────────────────────
//  Badge definitions
// ─────────────────────────────────────────────────────────────
class _Badge {
  const _Badge({
    required this.id,
    required this.emoji,
    required this.label,
    required this.desc,
  });
  final String id;
  final String emoji;
  final String label;
  final String desc;
}

const List<_Badge> _allBadges = [
  _Badge(id: 'first_question',   emoji: '🌱', label: 'First Question',   desc: 'Asked your very first question'),
  _Badge(id: '3_day_streak',     emoji: '🔥', label: '3 Day Streak',     desc: 'Learned 3 days in a row'),
  _Badge(id: '10_questions',     emoji: '🌟', label: '10 Questions',     desc: 'Asked 10 questions total'),
  _Badge(id: 'science_explorer', emoji: '🔬', label: 'Science Explorer', desc: '5+ science questions'),
  _Badge(id: 'math_wizard',      emoji: '📐', label: 'Math Wizard',      desc: '5+ math questions'),
  _Badge(id: 'geography_expert', emoji: '🗺️', label: 'Geography Expert', desc: '5+ social studies questions'),
  _Badge(id: 'speed_learner',    emoji: '⚡', label: 'Speed Learner',    desc: 'Answered 5 questions in one day'),
];

// ─────────────────────────────────────────────────────────────
//  Progress Screen
// ─────────────────────────────────────────────────────────────
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
    required this.childId,
    required this.backendBaseUrl,
  });

  final String childId;
  final String backendBaseUrl;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _barController;
  int? _tappedWeeklyBar;
  int? _tappedMonthlyBar;

  @override
  void initState() {
    super.initState();
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<StreakProvider>().fetchProgress(
            context.read<LanguageProvider>().childId,
            widget.backendBaseUrl,
          );
      if (mounted) _barController.forward();
    });
  }

  @override
  void dispose() {
    _barController.dispose();
    super.dispose();
  }

  // ─── Hero stats ───────────────────────────────────────────
  Widget _buildHeroStats(ProgressData data, String lang) {
    final cards = [
      _HeroCard(
        emoji: '🔥',
        value: data.streakDays,
        label: AppStrings.get('day_streak_label', lang),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      _HeroCard(
        emoji: '⭐',
        value: data.badges.length,
        label: AppStrings.get('stars_earned', lang),
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBC05), Color(0xFFF49B0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      _HeroCard(
        emoji: '📚',
        value: data.totalQuestions,
        label: AppStrings.get('questions', lang),
        gradient: const LinearGradient(
          colors: [Color(0xFF4285F4), Color(0xFF1A73E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      _HeroCard(
        emoji: '🎯',
        value: data.todayQuestions,
        total: data.dailyGoal,
        label: AppStrings.get('today', lang),
        gradient: const LinearGradient(
          colors: [Color(0xFF34A853), Color(0xFF0F9D58)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ];

    return Container(
      constraints: const BoxConstraints(minHeight: 100, maxHeight: 130),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => cards[i]
            .animate()
            .fadeIn(delay: Duration(milliseconds: 80 * i), duration: 500.ms)
            .slideY(begin: 0.3),
      ),
    );
  }

  // ─── Bar chart (weekly / monthly) ────────────────────────
  Widget _buildBarChart({
    required List<int> values,
    required List<String> labels,
    required String title,
    required String subtitle,
    required int? tappedIndex,
    required ValueChanged<int?> onTap,
    required Color activeColor,
    required bool isWeekly,
  }) {
    final maxVal = values.isEmpty ? 1 : values.reduce(math.max);
    final safeMax = maxVal == 0 ? 1 : maxVal;

    // Today's index for weekly chart
    final todayWeekday = DateTime.now().weekday; // 1=Mon..7=Sun
    final todayBarIdx = isWeekly ? todayWeekday - 1 : -1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurface,
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                  ),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: kTextSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(values.length, (i) {
                    final ratio = values[i] / safeMax;
                    final isActive = i == todayBarIdx;
                    final isTapped = tappedIndex == i;
                    final barColor = isActive ? activeColor : const Color(0xFFBBD6FC);

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onTap(isTapped ? null : i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (isTapped)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: kTextPrimary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: FittedBox(
                                    child: Text(
                                      '${values[i]}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ).animate().fadeIn(duration: 200.ms).scale(),
                              ),
                            const SizedBox(height: 4),
                            AnimatedBuilder(
                              animation: _barController,
                              builder: (_, __) {
                                final progress = CurvedAnimation(
                                  parent: _barController,
                                  curve: Curves.easeOutCubic,
                                ).value;
                                final height = math.max(4.0, 90 * ratio * progress);
                                return Container(
                                  width: double.infinity,
                                  height: height,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                                    color: barColor,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                if (maxVal == 0)
                  Center(
                    child: Text(
                      'Start learning to see your progress!',
                      style: TextStyle(
                        fontSize: 14,
                        color: kTextSecondary.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              labels.length,
              (i) => Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == todayBarIdx
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: i == todayBarIdx ? activeColor : kTextSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Subject breakdown ────────────────────────────────────
  Widget _buildSubjectBreakdown(ProgressData data) {
    const subjects = [
      _SubjectDef(key: 'math',          label: 'Math',          emoji: '📐', color: Color(0xFF4285F4)),
      _SubjectDef(key: 'science',       label: 'Science',       emoji: '🔬', color: Color(0xFF34A853)),
      _SubjectDef(key: 'social_studies',label: 'Social Studies',emoji: '🌍', color: Color(0xFFFBBC05)),
      _SubjectDef(key: 'other',         label: 'Other',         emoji: '💡', color: Color(0xFFEA4335)),
    ];

    final total =
        data.subjectBreakdown.values.fold(0, (a, b) => a + b);
    final safeTotal = total == 0 ? 1 : total;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurface,
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
          Text(
            AppStrings.get('what_explored', context.watch<LanguageProvider>().language),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...subjects.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final count = data.subjectBreakdown[s.key] ?? 0;
            final ratio = count / safeTotal;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(s.emoji,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '$count ${count == 1 ? "question" : "questions"}',
                        style: TextStyle(
                            fontSize: 12, color: kTextSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: AnimatedBuilder(
                      animation: _barController,
                      builder: (_, __) {
                        final progress = CurvedAnimation(
                          parent: _barController,
                          curve: Curves.easeOutCubic,
                        ).value;
                        return LinearProgressIndicator(
                          value: ratio * progress,
                          minHeight: 10,
                          backgroundColor: s.color.withOpacity(0.15),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(s.color),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(
                    delay: Duration(milliseconds: 100 + i * 60),
                    duration: 400.ms)
                .slideX(begin: 0.15);
          }),
        ],
      ),
    );
  }

  // ─── Badges ───────────────────────────────────────────────
  Widget _buildBadges(ProgressData data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurface,
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
          Text(
            AppStrings.get('my_achievements', context.watch<LanguageProvider>().language),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.60,
            ),
            itemCount: _allBadges.length,
            itemBuilder: (context, i) {
              final badge = _allBadges[i];
              final earned = data.badges.contains(badge.id);
              return GestureDetector(
                onTap: () => _showBadgeInfo(badge, earned),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: earned
                            ? const Color(0xFFFFF8E1)
                            : Colors.grey.shade100,
                        border: Border.all(
                          color: earned
                              ? const Color(0xFFFBBC05)
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                        boxShadow: earned
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFBBC05)
                                      .withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: earned
                          ? Center(
                              child: Text(badge.emoji,
                                  style:
                                      const TextStyle(fontSize: 26)))
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(badge.emoji,
                                    style: TextStyle(
                                        fontSize: 24,
                                        color: Colors.grey.shade300)),
                                Icon(Icons.lock_rounded,
                                    size: 20,
                                    color:
                                        Colors.grey.shade400),
                              ],
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      badge.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: earned
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color:
                            earned ? kTextPrimary : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(
                      delay: Duration(milliseconds: 60 * i),
                      duration: 400.ms)
                  .scale(
                      begin: const Offset(0.7, 0.7),
                      end: const Offset(1.0, 1.0));
            },
          ),
        ],
      ),
    );
  }

  void _showBadgeInfo(_Badge badge, bool earned) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(child: Text(badge.label)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(badge.desc,
                style: const TextStyle(color: kTextSecondary)),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: earned
                    ? const Color(0xFF34A853).withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                earned ? '✅ Earned!' : '🔒 Not yet earned',
                style: TextStyle(
                  color: earned ? const Color(0xFF34A853) : kTextSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().language;
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: BackButton(color: kTextPrimary),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                AppStrings.get('my_progress', lang),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Consumer<StreakProvider>(
            builder: (_, sp, __) => sp.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: kGoogleBlue),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: sp.progress.difficultyLevel == 'hard' 
                              ? Colors.orange.withOpacity(0.1)
                              : sp.progress.difficultyLevel == 'easy'
                                  ? Colors.green.withOpacity(0.1)
                                  : kGoogleBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sp.progress.difficultyLevel == 'hard' 
                              ? Colors.orange
                              : sp.progress.difficultyLevel == 'easy'
                                  ? Colors.green
                                  : kGoogleBlue,
                          )
                        ),
                        child: Text(
                          sp.progress.difficultyLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: sp.progress.difficultyLevel == 'hard' 
                              ? Colors.orange.shade800
                              : sp.progress.difficultyLevel == 'easy'
                                  ? Colors.green.shade800
                                  : kGoogleBlue,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: kTextSecondary),
                        onPressed: () async {
                          _barController.reset();
                          await context.read<StreakProvider>().fetchProgress(
                                context.read<LanguageProvider>().childId,
                                widget.backendBaseUrl,
                              );
                          _barController.forward();
                        },
                      ),
                    ],
                  ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Consumer<StreakProvider>(
        builder: (context, sp, _) {
          final data = sp.progress;

          // Weekly chart data
          final weeklyValues = data.weeklyData.map((e) => e.questions).toList();
          final weeklyLabels = data.weeklyData.map((e) => _translateDay(e.day, lang)).toList();

          // Monthly chart data
          final monthlyValues =
              data.monthlyData.map((e) => e.questions).toList();
          final monthlyLabels = data.monthlyData.map((e) => e.week).toList();

          // Date range for weekly subtitle
          String weekSubtitle = '';
          if (data.weeklyData.length == 7) {
            weekSubtitle =
                '${data.weeklyData.first.date} – ${data.weeklyData.last.date}';
          }

          return RefreshIndicator(
            color: kGoogleBlue,
            onRefresh: () async {
              _barController.reset();
              await sp.fetchProgress(context.read<LanguageProvider>().childId, widget.backendBaseUrl);
              _barController.forward();
            },
            child: ListView(
              padding: const EdgeInsets.only(top: 20, bottom: 32),
              children: [
                // ── Motivational Message ──
                _buildMotivationalMessage(data.streakDays, lang),
                const SizedBox(height: 16),
                
                // ── Hero stats ──
                _buildHeroStats(data, lang),
                const SizedBox(height: 20),

                // ── Streak Calendar ──
                StreakCalendar(
                  weeklyData: data.weeklyData,
                  lang: lang,
                ),
                const SizedBox(height: 8),

                // ── Section label ──
                _sectionLabel(AppStrings.get('this_week', lang)),
                _buildBarChart(
                  values: weeklyValues,
                  labels: weeklyLabels,
                  title: AppStrings.get('this_week', lang),
                  subtitle: weekSubtitle,
                  tappedIndex: _tappedWeeklyBar,
                  onTap: (i) => setState(() => _tappedWeeklyBar = i),
                  activeColor: kGoogleBlue,
                  isWeekly: true,
                ),
                const SizedBox(height: 8),

                // ── Monthly ──
                _sectionLabel(AppStrings.get('this_month', lang)),
                _buildBarChart(
                  values: monthlyValues,
                  labels: monthlyLabels,
                  title: AppStrings.get('this_month', lang),
                  subtitle: '',
                  tappedIndex: _tappedMonthlyBar,
                  onTap: (i) => setState(() => _tappedMonthlyBar = i),
                  activeColor: kGoogleGreen,
                  isWeekly: false,
                ),
                const SizedBox(height: 8),

                // ── Subjects ──
                _sectionLabel(AppStrings.get('subjects', lang)),
                _buildSubjectBreakdown(data),
                const SizedBox(height: 8),

                // ── Badges ──
                _sectionLabel(AppStrings.get('my_achievements', lang)),
                _buildBadges(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: kTextSecondary.withOpacity(0.6),
          ),
        ),
      );

  final motivationalMessages = {
    'english': {
      0: '🚀 Start your learning journey today!',
      1: '💪 Good start! Keep going!',
      3: '🔥 You\'re on fire! Don\'t break the streak!',
      7: '🌟 Incredible! You\'re a true scholar!',
    },
    'kannada': {
      0: '🚀 ಇಂದು ನಿಮ್ಮ ಕಲಿಕೆಯ ಪ್ರಯಾಣ ಪ್ರಾರಂಭಿಸಿ!',
      1: '💪 ಒಳ್ಳೆಯ ಪ್ರಾರಂಭ! ಮುಂದುವರಿಯಿರಿ!',
      3: '🔥 ನೀವು ಅದ್ಭುತವಾಗಿದ್ದೀರಿ! ಸ್ಟ್ರೀಕ್ ಮುರಿಯಬೇಡಿ!',
      7: '🌟 ಅದ್ಭುತ! ನೀವು ನಿಜವಾದ ವಿದ್ವಾಂಸರು!',
    },
    'hindi': {
      0: '🚀 आज अपनी सीखने की यात्रा शुरू करें!',
      1: '💪 अच्छी शुरुआत! जारी रखो!',
      3: '🔥 तुम आग पर हो! स्ट्रीक मत तोड़ो!',
      7: '🌟 अविश्वसनीय! तुम सच्चे विद्वान हो!',
    },
    'tamil': {
      0: '🚀 இன்று உங்கள் கற்றல் பயணத்தை தொடங்குங்கள்!',
      1: '💪 நல்ல தொடக்கம்! தொடர்ந்து செல்லுங்கள்!',
      3: '🔥 நீங்கள் அற்புதமாக இருக்கிறீர்கள்!',
      7: '🌟 நம்பமுடியாதது! நீங்கள் உண்மையான அறிஞர்!',
    },
  };

  Widget _buildMotivationalMessage(int streakDays, String lang) {
    final messages = motivationalMessages[lang] ?? motivationalMessages['english']!;
    
    String msg;
    String emoji;
    
    if (streakDays >= 7) {
      msg = messages[7]!.substring(2).trim();
      emoji = messages[7]!.substring(0, 2).trim();
    } else if (streakDays >= 3) {
      msg = messages[3]!.substring(2).trim();
      emoji = messages[3]!.substring(0, 2).trim();
    } else if (streakDays >= 1) {
      msg = messages[1]!.substring(2).trim();
      emoji = messages[1]!.substring(0, 2).trim();
    } else {
      msg = messages[0]!.substring(2).trim();
      emoji = messages[0]!.substring(0, 2).trim();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.purple.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _translateDay(String day, String lang) {
    if (lang == 'english') return day;
    final Map<String, List<String>> maps = {
      'kannada': ['ಭಾನು','ಸೋಮ','ಮಂಗಳ','ಬುಧ','ಗುರು','ಶುಕ್ರ','ಶನಿ'],
      'hindi':   ['रवि','सोम','मंगल','बुध','गुरु','शुक','शनि'],
      'tamil':   ['ஞாயி','திங்','செவ்','புத','வியா','வெள்','சனி'],
      'english': ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
    };
    final englishDays = maps['english']!;
    final index = englishDays.indexOf(day);
    if (index == -1) return day;
    return maps[lang]?[index] ?? day;
  }
}

// ─────────────────────────────────────────────────────────────
//  Helper widgets
// ─────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.emoji,
    required this.value,
    this.total,
    required this.label,
    required this.gradient,
  });

  final String emoji;
  final int value;
  final int? total;
  final String label;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      constraints: const BoxConstraints(minHeight: 100, maxHeight: 130),
      padding: const EdgeInsets.all(12),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value.toDouble()),
              duration: const Duration(seconds: 1),
              curve: Curves.easeOut,
              builder: (context, val, child) {
                final strVal = val.toInt().toString();
                final displayStr = total != null ? '$strVal/$total' : strVal;
                return Text(
                  displayStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectDef {
  const _SubjectDef({
    required this.key,
    required this.label,
    required this.emoji,
    required this.color,
  });
  final String key;
  final String label;
  final String emoji;
  final Color color;
}
