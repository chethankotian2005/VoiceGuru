import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/voiceguru_models.dart';
import '../services/api_service.dart';
import '../l10n/app_strings.dart';
import '../providers/language_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.backendBaseUrl,
    required this.childId,
    required this.refreshToken,
  });

  final String backendBaseUrl;
  final String childId;
  final int refreshToken;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final ApiService _api;
  List<VoiceGuruHistoryEntry> _entries = [];
  bool _loading = true;
  String _activeFilter = 'All';

  static const _filters = ['All', 'Math', 'Science', 'Social Studies'];

  @override
  void initState() {
    super.initState();
    _api = ApiService(baseUrl: widget.backendBaseUrl);
    _loadHistory();
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final childId = context.read<LanguageProvider>().childId;
      final raw = await _api.getHistory(childId);
      _entries = raw
          .whereType<Map>()
          .map((item) => VoiceGuruHistoryEntry.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ))
          .toList()
        ..sort((a, b) =>
            (b.timestamp ?? DateTime(2000)).compareTo(a.timestamp ?? DateTime(2000)));
    } catch (_) {
      _entries = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<VoiceGuruHistoryEntry> get _filteredEntries {
    if (_activeFilter == 'All') return _entries;
    return _entries.where((e) {
      final s = e.subject.toLowerCase();
      final f = _activeFilter.toLowerCase();
      return s.contains(f);
    }).toList();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().language;
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          AppStrings.get('my_journey', lang),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: kTextPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final f = _filters[i];
                    final isActive = _activeFilter == f;
                    return FilterChip(
                      label: Text(
                        f,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : kTextPrimary,
                        ),
                      ),
                      selected: isActive,
                      selectedColor: kGoogleBlue,
                      backgroundColor: kBackground,
                      side: BorderSide(
                        color: isActive ? kGoogleBlue : Colors.grey.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onSelected: (_) {
                        setState(() => _activeFilter = f);
                      },
                    );
                  },
                ),
              ),
              Container(height: 1, color: Colors.grey.shade200),
            ],
          ),
        ),
      ),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: 3,
              itemBuilder: (context, i) => const _SkeletonCard(),
            )
          : _filteredEntries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📚', style: TextStyle(fontSize: 72))
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .moveY(begin: 0, end: -10, duration: 1500.ms),
                      const SizedBox(height: 16),
                      Text(AppStrings.get('no_questions', lang),
                        style: const TextStyle(fontSize: 20, 
                          fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 8),
                      Text(AppStrings.get('start_journey_msg', lang),
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGoogleBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Start Learning →', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: kGoogleBlue,
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _filteredEntries.length,
                    itemBuilder: (context, i) =>
                        _HistoryCard(entry: _filteredEntries[i], lang: lang),
                  ),
                ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 13,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Container(
                    height: 13,
                    width: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Container(
                    height: 18,
                    width: 90,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(
          duration: 1200.ms,
          color: Colors.grey.shade100,
        );
  }
}


class _HistoryCard extends StatefulWidget {
  final VoiceGuruHistoryEntry entry;
  final String lang;
  const _HistoryCard({required this.entry, required this.lang});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _expanded = false;

  Color _colorForSubject(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('math')) return kGoogleBlue;
    if (lower.contains('science')) return kGoogleGreen;
    if (lower.contains('social')) return kGoogleYellow;
    return kTextSecondary;
  }

  String _emojiForSubject(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('math')) return '📐';
    if (lower.contains('science')) return '🔬';
    if (lower.contains('social')) return '🗺️';
    return '💡';
  }

  String _formatDate(DateTime? dt, String lang) {
    if (dt == null) return '';
    final monthsEn = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final monthsKn = ['ಜನವರಿ','ಫೆಬ್ರವರಿ','ಮಾರ್ಚ್','ಏಪ್ರಿಲ್','ಮೇ','ಜೂನ್','ಜುಲೈ','ಆಗಸ್ಟ್','ಸೆಪ್ಟೆಂಬರ್','ಅಕ್ಟೋಬರ್','ನವೆಂಬರ್','ಡಿಸೆಂಬರ್'];
    final monthsHi = ['जनवरी','फ़रवरी','मार्च','अप्रैल','मई','जून','जुलाई','अगस्त','सितंबर','अक्टूबर','नवंबर','दिसंबर'];
    final monthsTa = ['ஜனவரி','பிப்ரவரி','மார்ச்','ஏப்ரல்','மே','ஜூன்','ஜூலை','ஆகஸ்ட்','செப்டம்பர்','அக்டோபர்','நவம்பர்','டிசம்பர்'];

    final monthIndex = dt.month - 1;
    String monthStr;
    String amPm = dt.hour >= 12 ? 'PM' : 'AM';
    
    if (lang == 'kannada') {
      monthStr = monthsKn[monthIndex];
      amPm = dt.hour >= 12 ? 'ಸಂಜೆ' : 'ಬೆಳಗ್ಗೆ';
    } else if (lang == 'hindi') {
      monthStr = monthsHi[monthIndex];
      amPm = dt.hour >= 12 ? 'शाम' : 'सुबह';
    } else if (lang == 'tamil') {
      monthStr = monthsTa[monthIndex];
      amPm = dt.hour >= 12 ? 'பிற்பகல்' : 'காலை';
    } else {
      monthStr = monthsEn[monthIndex];
    }

    int hour = dt.hour % 12;
    if (hour == 0) hour = 12;
    final minute = dt.minute.toString().padLeft(2, '0');

    return '${dt.day} $monthStr, $hour:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final subjectColor = _colorForSubject(widget.entry.subject);
    final subjectEmoji = _emojiForSubject(widget.entry.subject);
    final dateStr = _formatDate(widget.entry.timestamp, widget.lang);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: kSurface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Color strip
              Container(width: 5, color: subjectColor),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.entry.question,
                        maxLines: _expanded ? null : 2,
                        overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Subject badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: subjectColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$subjectEmoji ${widget.entry.subject}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: subjectColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Date
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      // Expanded explanation
                      AnimatedCrossFade(
                        firstChild: const SizedBox(width: double.infinity, height: 0),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Divider(color: Colors.grey.shade200, height: 1),
                              const SizedBox(height: 12),
                              Text(
                                widget.entry.explanation,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: kTextPrimary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 300),
                      ),
                    ],
                  ),
                ),
              ),
              // Chevron
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Center(
                  child: AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

