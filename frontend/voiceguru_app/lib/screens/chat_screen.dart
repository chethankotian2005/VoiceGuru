import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

import '../main.dart';
import '../services/api_service.dart';
import '../models/voiceguru_models.dart';
import '../services/tts_service.dart';
import '../services/voice_service.dart';
import '../widgets/diagram_widget.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';
import 'quiz_screen.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/streak_provider.dart';
import '../l10n/app_strings.dart';
import '../widgets/level_badge.dart';
import '../widgets/owl_reactions.dart';
import '../widgets/xp_toast.dart';
import '../widgets/streak_widget.dart';
import '../l10n/app_strings.dart';

// ─── Smooth slide-right page transition ───
Route<T> _slideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 280),
  );
}

// ─────────────────────────────────────────────
//  Chat Message Model
// ─────────────────────────────────────────────
enum MessageSender { user, ai }
enum InputType { voice, text }

String _sanitizeForUi(String input) {
  final codeUnits = input.codeUnits;
  final out = StringBuffer();

  for (var i = 0; i < codeUnits.length; i++) {
    final cu = codeUnits[i];

    // Keep valid surrogate pairs, replace malformed surrogate code units.
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

class ChatMessage {
  ChatMessage({
    required this.sender,
    required String text,
    this.inputType = InputType.text,
    this.imageFile,
    this.subject,
    this.needsDiagram = false,
    this.diagramType = 'none',
    this.diagramDescription,
    this.youtubeSearchQuery,
    this.keyTerms = const [],
    this.youtubeResults = const [],
    this.isLoading = false,
    this.steps = const [],
    this.finalAnswer,
    this.hint,
  }) : text = _sanitizeForUi(text);

  final MessageSender sender;
  String text;
  final InputType inputType;
  final File? imageFile;
  final String? subject;
  final bool needsDiagram;
  final String diagramType;
  final String? diagramDescription;
  final String? youtubeSearchQuery;
  final List<String> keyTerms;
  List<Map<String, dynamic>> youtubeResults;
  bool isLoading;
  // Step-by-step homework solving
  final List<String> steps;
  final String? finalAnswer;
  final String? hint;
}

// ─────────────────────────────────────────────
//  Hotword State
// ─────────────────────────────────────────────
enum HotwordState { listening, detected, processing, idle }

// ─────────────────────────────────────────────
//  Chat Screen
// ─────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.backendBaseUrl,
    required this.childId,
    this.isGuest = false,
  });

  final String backendBaseUrl;
  final String childId;
  final bool isGuest;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late final ApiService _api;
  late final TtsService _tts;
  late final VoiceService _voice;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocus = FocusNode();

  int _selectedIndex = 0;
  bool _hasShownWelcome = false;
  Color _currentSubjectColor = const Color(0xFF4285F4);

  final List<ChatMessage> _messages = [];
  List<Suggestion> _suggestions = [];
  bool _isSuggestionsLoading = true;
  HotwordState _hotwordState = HotwordState.idle;
  bool _isRecording = false;
  bool _hasText = false;
  String? _detectedLanguage;
  String? _speakingLanguage;

  // Pulse animation for mic
  late AnimationController _pulseController;

  // Confetti controller for streak celebration
  late ConfettiController _confettiController;
  int _prevStreak = 0;

  // Gamification states
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _showXpToast = false;
  bool _showStreakCelebration = false;
  MascotState _mascotState = MascotState.idle;

  Future<void> _loadSuggestions() async {
    if (!mounted) return;
    setState(() => _isSuggestionsLoading = true);
    
    final lang = context.read<LanguageProvider>().language;
    final grade = context.read<LanguageProvider>().grade;
    
    final results = await _api.getSuggestions(
      grade: grade,
      language: lang,
    );
    
    if (mounted) {
      setState(() {
        _suggestions = results.map((e) => Suggestion.fromJson(e)).toList();
        _isSuggestionsLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _speakingLanguage = context.read<LanguageProvider>().language;
    _api = ApiService(baseUrl: widget.backendBaseUrl);
    _tts = TtsService(baseUrl: widget.backendBaseUrl);
    _tts.initialize();
    _voice = VoiceService();
    _voice.setLanguage(context.read<LanguageProvider>().language);
    _voice.initialize();

    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Fetch progress on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProgress();
    });

    _loadSuggestions();
  }

  @override
  void dispose() {
    _api.dispose();
    _tts.dispose();
    _voice.dispose();
    _scrollController.dispose();
    _textController.dispose();
    _textFocus.dispose();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(String name) async {
    try {
      await _audioPlayer.setAsset('assets/sounds/$name.wav');
      await _audioPlayer.play();
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Send question (text) ───
  Future<void> _sendQuestion(String questionText, {InputType type = InputType.text}) async {
    if (questionText.trim().isEmpty) return;

    HapticFeedback.lightImpact();
    _playSound('pop');

    setState(() {
      if (!_hasShownWelcome) _hasShownWelcome = true;
      _mascotState = MascotState.thinking;
      _messages.add(ChatMessage(
        sender: MessageSender.user,
        text: questionText.trim(),
        inputType: type,
      ));
      _messages.add(ChatMessage(
        sender: MessageSender.ai,
        text: '',
        isLoading: true,
      ));
      _hotwordState = HotwordState.processing;
    });
    _textController.clear();
    _scrollToBottom();

    final currentGrade = context.read<LanguageProvider>().grade;

    try {
      final result = await _api.askQuestion(
        text: questionText.trim(),
        language: _speakingLanguage ?? context.read<LanguageProvider>().language,
        grade: currentGrade,
        childId: context.read<LanguageProvider>().childId,
      );

      // Fetch YouTube results if there's a search query
      List<Map<String, dynamic>> ytResults = [];
      final ytQuery = result['youtube_search_query']?.toString();
      if (ytQuery != null && ytQuery.isNotEmpty) {
        ytResults = await _api.youtubeSearch(query: ytQuery, grade: currentGrade);
      }

      setState(() {
        _messages.removeLast(); // Remove loading message

        final subject = result['subject']?.toString().toLowerCase() ?? 'general';
        if (subject == 'math') {
          _currentSubjectColor = const Color(0xFF4285F4);
        } else if (subject == 'science') {
          _currentSubjectColor = const Color(0xFF34A853);
        } else if (subject == 'social_studies' || subject == 'social studies') {
          _currentSubjectColor = const Color(0xFFF4B400);
        } else {
          _currentSubjectColor = const Color(0xFF4285F4);
        }

        _messages.add(ChatMessage(
          sender: MessageSender.ai,
          text: result['explanation']?.toString() ?? '',
          subject: result['subject']?.toString(),
          needsDiagram: result['needs_diagram'] == true,
          diagramType: result['diagram_type']?.toString() ?? 'none',
          diagramDescription: result['diagram_description']?.toString(),
          youtubeSearchQuery: ytQuery,
          keyTerms: (result['key_terms'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          youtubeResults: ytResults,
        ));
        _hotwordState = HotwordState.idle;
        _detectedLanguage = result['language']?.toString();
        _mascotState = MascotState.bouncy;
        _showXpToast = true;
      });
      HapticFeedback.mediumImpact();
      _playSound('chime');
      _scrollToBottom();

      // Auto speak the response
      await _speak(result['explanation']?.toString() ?? '');

      // Refresh progress after successful answer
      _fetchProgress();

    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(
          sender: MessageSender.ai,
          text: 'Something went wrong. Please try again.',
        ));
        _hotwordState = HotwordState.idle;
      });
      _scrollToBottom();
    }
  }

  // ─── Pick Image ───
  Future<void> _handleImagePick() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a Photo'),
                subtitle: const Text('Use camera to capture your question'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageAndSend(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Pick an image from your phone'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageAndSend(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageAndSend(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      setState(() {
        _messages.add(ChatMessage(
          sender: MessageSender.user,
          text: '',
          imageFile: file,
        ));
        _messages.add(ChatMessage(
          sender: MessageSender.ai,
          text: '',
          isLoading: true,
        ));
        _hotwordState = HotwordState.processing;
      });
      _scrollToBottom();

      if (!mounted) return;
      final currentGrade = context.read<LanguageProvider>().grade;
      final language = context.read<LanguageProvider>().language;

      final result = await _api.askImage(
        imageBase64: base64Image,
        language: _speakingLanguage ?? language,
        grade: currentGrade,
        childId: context.read<LanguageProvider>().childId,
        additionalContext: _textController.text.trim(),
      );

      _textController.clear();

      List<Map<String, dynamic>> ytResults = [];
      final ytQuery = result['youtube_search_query']?.toString();
      if (ytQuery != null && ytQuery.isNotEmpty) {
        ytResults = await _api.youtubeSearch(query: ytQuery, grade: currentGrade);
      }

      if (!mounted) return;
      setState(() {
        _messages.removeLast(); // Remove loading message

        final rawSteps = result['steps'];
        final stepsList = (rawSteps is List)
            ? rawSteps.map((e) => e.toString()).toList()
            : <String>[];

        _messages.add(ChatMessage(
          sender: MessageSender.ai,
          text: result['explanation']?.toString() ?? '',
          subject: result['subject']?.toString(),
          needsDiagram: result['needs_diagram'] == true,
          diagramType: result['diagram_type']?.toString() ?? 'none',
          diagramDescription: result['diagram_description']?.toString(),
          youtubeSearchQuery: ytQuery,
          keyTerms: (result['key_terms'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          youtubeResults: ytResults,
          steps: stepsList,
          finalAnswer: result['final_answer']?.toString(),
          hint: result['hint']?.toString(),
        ));
        _hotwordState = HotwordState.idle;
      });
      _scrollToBottom();
      _fetchProgress();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(
          sender: MessageSender.ai,
          text: 'I could not process the image properly. Please try again.',
        ));
        _hotwordState = HotwordState.idle;
      });
    }
  }

  // ─── Simplify ───
  Future<void> _simplify(int messageIndex) async {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;
    final original = _messages[messageIndex];

    // Find the user message that triggered this
    String question = '';
    for (var i = messageIndex - 1; i >= 0; i--) {
      if (_messages[i].sender == MessageSender.user) {
        question = _messages[i].text;
        break;
      }
    }

    setState(() {
      _messages.add(ChatMessage(
        sender: MessageSender.ai,
        text: '',
        isLoading: true,
      ));
    });
    _scrollToBottom();

    try {
      final result = await _api.simplify(
        originalQuestion: question,
        originalExplanation: original.text,
        language: context.read<LanguageProvider>().language,
        grade: context.read<LanguageProvider>().grade,
        childId: context.read<LanguageProvider>().childId,
      );

      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(
          sender: MessageSender.ai,
          text: result['simplified_explanation']?.toString() ??
              'Could not simplify right now.',
        ));
      });
      _scrollToBottom();
    } catch (_) {
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(
          sender: MessageSender.ai,
          text: 'Could not simplify right now. Try again.',
        ));
      });
      _scrollToBottom();
    }
  }

  // ─── TTS ───
  Future<void> _speak(String text) async {
    await _tts.speak(text, _detectedLanguage ?? _speakingLanguage ?? context.read<LanguageProvider>().language);
  }

  // ——— Recording (on-device STT via speech_to_text) ———
  Future<void> _handleMicTap() async {
    HapticFeedback.mediumImpact();
    if (_isRecording) {
      await _stopRecording();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.get('speaking_in', context.read<LanguageProvider>().language),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: ['english', 'kannada', 'hindi', 'tamil'].map((lang) {
                final isSelected = _speakingLanguage == lang;
                return ChoiceChip(
                  label: Text({
                    'english': 'English',
                    'kannada': 'ಕನ್ನಡ',
                    'hindi': 'हिंदी',
                    'tamil': 'தமிழ்',
                  }[lang]!),
                  selected: isSelected,
                  selectedColor: kGoogleBlue.withOpacity(0.2),
                  backgroundColor: kBackground,
                  labelStyle: TextStyle(
                    color: isSelected ? kGoogleBlue : kTextSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) {
                    _voice.updateLocale(lang);
                    setState(() => _speakingLanguage = lang);
                    Navigator.pop(context);
                    _startRecording();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    await _voice.startListening(
      onResult: (String text) {
        _pulseController.stop();
        _pulseController.reset();
        setState(() {
          _isRecording = false;
          _hotwordState = HotwordState.processing;
        });
        if (text.isNotEmpty) {
          _sendQuestion(text, type: InputType.voice);
        } else {
          setState(() => _hotwordState = HotwordState.idle);
        }
      },
      onListeningStarted: () {
        HapticFeedback.lightImpact();
        setState(() => _isRecording = true);
        _pulseController.repeat(reverse: true);
      },
      onListeningStopped: () {
        _pulseController.stop();
        _pulseController.reset();
        setState(() => _isRecording = false);
      },
    );
  }

  Future<void> _stopRecording() async {
    _pulseController.stop();
    _pulseController.reset();
    await _voice.stopListening();
    setState(() => _isRecording = false);
  }

  // ─────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────

  /// Fetches progress and triggers confetti if the streak increased.
  void _fetchProgress() {
    final sp = context.read<StreakProvider>();
    sp.fetchProgress(context.read<LanguageProvider>().childId, widget.backendBaseUrl).then((_) {
      if (!mounted) return;
      final spRead = context.read<StreakProvider>();

      if (spRead.streakJustIncreased) {
        _confettiController.play();
        // _playSound('levelup'); // Disabled annoying beep on startup
        setState(() => _mascotState = MascotState.happy);
      }

      // Daily goal celebration
      if (spRead.goalJustMet) {
        // _playSound('levelup'); // Disabled annoying beep
        HapticFeedback.heavyImpact();
        setState(() {
          _showStreakCelebration = true;
          _mascotState = MascotState.happy;
        });
      }

      if (spRead.levelJustIncreased) {
        _confettiController.play();
        // _playSound('levelup'); // Disabled annoying beep
        setState(() => _mascotState = MascotState.happy);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Level Up! 🎉', textAlign: TextAlign.center),
            content: Text(
              'You are now Level ${spRead.level}!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Awesome!'),
              ),
            ],
          ),
        );
      }

      spRead.clearJustIncreasedFlags();
    });
  }

  // ─────────────────────────────────────────────
  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().language;
    final sp = context.watch<StreakProvider>();
    final quizAvailable = sp.progress.todayQuestions >= 3 && !widget.isGuest;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: _selectedIndex == 0 ? _buildAppBar() : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Tab 0: Chat
          Stack(
            children: [
              Column(
                children: [
                  // Streak banner
                  if (!widget.isGuest) _buildStreakBanner(),
                  // Hotword status bar
                  _buildStatusBar(),
                  // Chat messages
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _messages.isEmpty
                          ? _buildSuggestionsGrid()
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) =>
                                  _buildMessage(_messages[index], index),
                            ),
                    ),
                  ),
                  // Quiz notification banner
                  _buildQuizBanner(),
                  // Input bar
                  _buildInputBar(),
                ],
              ),
              // Confetti overlay
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 30,
                  gravity: 0.3,
                  colors: const [
                    kGoogleBlue,
                    kGoogleGreen,
                    kGoogleYellow,
                    kGoogleRed,
                    Colors.purple,
                  ],
                ),
              ),

              // XP Toast
              if (_showXpToast)
                XPToast(
                  onComplete: () {
                    if (mounted) setState(() => _showXpToast = false);
                  },
                ),
              // Streak Celebration Overlay
              if (_showStreakCelebration)
                StreakCelebrationOverlay(
                  streak: context.read<StreakProvider>().progress.streakDays,
                  onDismiss: () {
                    if (mounted) setState(() => _showStreakCelebration = false);
                  },
                ),
            ],
          ),
          // Tab 1: Progress
          ProgressScreen(
            childId: context.read<LanguageProvider>().childId,
            backendBaseUrl: widget.backendBaseUrl,
          ),
          // Tab 2: Quiz
          QuizScreen(
            grade: context.read<LanguageProvider>().grade,
            language: lang,
            childId: context.read<LanguageProvider>().childId,
            backendBaseUrl: widget.backendBaseUrl,
          ),
        ],
      ),
      bottomNavigationBar: widget.isGuest ? null : NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: AppStrings.get('learn', lang),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: AppStrings.get('progress', lang),
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: quizAvailable,
              child: const Icon(Icons.quiz_outlined),
            ),
            selectedIcon: const Icon(Icons.quiz),
            label: AppStrings.get('quiz', lang),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final lang = context.watch<LanguageProvider>().language;
    final name = context.watch<LanguageProvider>().childName;
    
    final String fallback = name.isEmpty ? 'Friend' : name;
    
    if (hour >= 5 && hour < 12) {
      return '${AppStrings.get('good_morning', lang)}, $fallback! 🌅';
    } else if (hour >= 12 && hour < 17) {
      return '${AppStrings.get('good_afternoon', lang)}, $fallback! ☀️';
    } else {
      return '${AppStrings.get('good_evening', lang)}, $fallback! 🌙';
    }
  }

  String _getSuggestionSubtitle() {
    final lang = context.watch<LanguageProvider>().language;
    return AppStrings.get('explore_today', lang);
  }

  Color _getCategoryColor(String category) {
    if (category == 'curriculum') return const Color(0xFF4285F4); // Google Blue
    if (category == 'curiosity') return const Color(0xFF34A853); // Google Green
    return const Color(0xFFFBBC05); // Google Yellow
  }

  Widget _buildWelcomeMessage() {
    final lang = context.watch<LanguageProvider>().language;
    final name = context.watch<LanguageProvider>().childName;
    final text = AppStrings.get('welcome_study_buddy', lang).replaceAll('{name}', name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('🦉', style: TextStyle(fontSize: 48))
            .animate()
            .slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.elasticOut)
            .fadeIn(duration: 400.ms),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: AnimatedTextKit(
                animatedTexts: [
                  TypewriterAnimatedText(
                    text,
                    speed: const Duration(milliseconds: 30),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF202124),
                      height: 1.4,
                    ),
                  ),
                ],
                isRepeatingAnimation: false,
                displayFullTextOnTap: true,
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 300.ms).scaleXY(begin: 0.9, end: 1.0, alignment: Alignment.bottomLeft),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsGrid() {
    final showWelcome = !_hasShownWelcome && _messages.isEmpty;
    final baseDelay = showWelcome ? 800.ms : 0.ms;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showWelcome) _buildWelcomeMessage(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _getGreeting(),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF202124),
                  ),
                ),
              ),
              IconButton(
                onPressed: _isSuggestionsLoading ? null : _loadSuggestions,
                icon: const Icon(Icons.refresh_rounded),
                color: const Color(0xFF4285F4),
              ),
            ],
          ).animate().fadeIn(delay: baseDelay, duration: 400.ms).slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text(
            _getSuggestionSubtitle(),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ).animate().fadeIn(delay: baseDelay + 100.ms, duration: 400.ms).slideY(begin: 0.2),
          const SizedBox(height: 24),
          
          if (_isSuggestionsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: Color(0xFF4285F4)),
              ),
            )
          else if (_suggestions.isNotEmpty)
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85, // Slightly wider for better text fit
              ),
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final s = _suggestions[index];
                final catColor = _getCategoryColor(s.category);
                
                return _SuggestionCard(
                  suggestion: s,
                  categoryColor: catColor,
                  index: index,
                  onTap: () {
                    _textController.text = s.query;
                    _sendQuestion(s.query);
                  },
                ).animate(
                  delay: baseDelay + Duration(milliseconds: index * 80),
                )
                 .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic)
                 .fadeIn(duration: 350.ms);
              },
            ),
        ],
      ),
    );
  }

  // ─── App Bar ───
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        color: _currentSubjectColor.withValues(alpha: 0.1),
        child: SafeArea(
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 1,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                Text(
                  'VoiceGuru',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kGoogleBlue,
                  ),
                ),
                const SizedBox(width: 8),
                if (!widget.isGuest)
                  Consumer<StreakProvider>(
                    builder: (_, sp, __) => LevelBadge(level: sp.level),
                  ),
              ],
            ),
          ),
          if (!widget.isGuest)
            Text(
              'Hi ${context.watch<LanguageProvider>().childName} 👋',
              style: TextStyle(
                fontSize: 13,
                color: kTextSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: [
        // History button
        IconButton(
          icon: const Icon(Icons.history_rounded, color: kTextSecondary),
          onPressed: () {
            Navigator.of(context).push(_slideRoute(HistoryScreen(
              backendBaseUrl: widget.backendBaseUrl,
              childId: context.read<LanguageProvider>().childId,
              refreshToken: 0,
            )));
          },
        ),
        // Avatar
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            onPressed: widget.isGuest ? null : () => Navigator.push(
              context,
              _slideRoute(const ProfileScreen()),
            ),
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: kGoogleBlue.withValues(alpha: 0.1),
              child: Text(
                widget.isGuest ? '👤' : context.watch<LanguageProvider>().childName[0].toUpperCase(),
                style: TextStyle(
                  fontSize: widget.isGuest ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: kGoogleBlue,
                ),
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey.shade200),
      ),
    ),
        ),
      ),
    );
  }

  // ─── Streak Banner ───
  Widget _buildStreakBanner() {
    return Consumer<StreakProvider>(
      builder: (_, sp, __) {
        final lang = context.watch<LanguageProvider>().language;
        final progress = sp.progress;
        return StreakBanner(
          streak: progress.streakDays,
          todayQuestions: progress.todayQuestions,
          dailyGoal: progress.dailyGoal,
          lang: lang,
          onTap: () => Navigator.of(context).push(_slideRoute(ProgressScreen(
            childId: context.read<LanguageProvider>().childId,
            backendBaseUrl: widget.backendBaseUrl,
          ))),
        );
      },
    );
  }

  // ─── Quiz Banner ───
  Widget _buildQuizBanner() {
    return Consumer<StreakProvider>(
      builder: (_, sp, __) {
        final today = sp.progress.todayQuestions;
        if (today < 3 || widget.isGuest) return const SizedBox.shrink();

        final langProvider = context.read<LanguageProvider>();
        return Container(
          color: Colors.purple.shade50,
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              const Text('📝', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Daily quiz is ready! Test what you learned today',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  _slideRoute(QuizScreen(
                    grade: langProvider.grade,
                    language: langProvider.language,
                    childId: context.read<LanguageProvider>().childId,
                    backendBaseUrl: widget.backendBaseUrl,
                  )),
                ),
                child: const Text('Start →'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Status Bar ───
  Widget _buildStatusBar() {
    final lang = context.watch<LanguageProvider>().language;
    if (_hotwordState == HotwordState.idle) {
      return const SizedBox.shrink();
    }

    IconData icon;
    String text;
    Color bgColor;
    Color textColor;

    switch (_hotwordState) {
      case HotwordState.listening:
        icon = Icons.hearing_rounded;
        text = AppStrings.get('listening', lang);
        bgColor = kGoogleGreen.withOpacity(0.1);
        textColor = kGoogleGreen;
        break;
      case HotwordState.detected:
        icon = Icons.mic_rounded;
        text = AppStrings.get('tap_mic', lang);
        bgColor = kGoogleBlue.withOpacity(0.1);
        textColor = kGoogleBlue;
        break;
      case HotwordState.processing:
        icon = Icons.auto_awesome;
        text = AppStrings.get('thinking', lang);
        bgColor = kGoogleYellow.withOpacity(0.1);
        textColor = kGoogleYellow.withOpacity(0.8);
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      height: 36,
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (_hotwordState == HotwordState.processing)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: textColor,
              ),
            )
          else
            Icon(icon, size: 16, color: textColor)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.3, 1.3),
                    duration: 800.ms),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Message Bubble ───
  Widget _buildMessage(ChatMessage msg, int index) {
    final isUser = msg.sender == MessageSender.user;

    if (msg.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: const _ThinkingBubble()
          .animate().fadeIn(duration: 300.ms).slideX(begin: -0.05),
      );
    }

    if (isUser) {
      return _buildUserBubble(msg);
    }
    return _buildAiBubble(msg, index);
  }

  Widget _buildUserBubble(ChatMessage msg) {
    if (msg.imageFile != null) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          constraints: const BoxConstraints(maxWidth: 220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(msg.imageFile!, height: 160, width: 200, fit: BoxFit.cover),
              ),
              const SizedBox(height: 4),
              const Text("📷 Photo question", style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF4285F4),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                msg.text,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            if (msg.inputType == InputType.voice) ...[
              const SizedBox(width: 6),
              const Icon(Icons.mic, size: 14, color: Colors.white70),
            ],
          ],
        ),
      ).animate()
        .slideY(begin: 0.3, end: 0, duration: 300.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 250.ms),
    );
  }

  Widget _buildAiBubble(ChatMessage msg, int index) {
    final lang = context.watch<LanguageProvider>().language;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6, right: 8),
          child: CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFFEFF6FF), // blue.shade50
            child: Text('🦉', style: TextStyle(fontSize: 14)),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.90,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade100),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section A - Explanation text
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: _TypewriterText(text: msg.text),
                  ),

                  // Section A2 - Step-by-step card (image analysis only)
                  if (msg.steps.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: StepByStepCard(
                        steps: msg.steps,
                        finalAnswer: msg.finalAnswer ?? '',
                        hint: msg.hint,
                      ),
                    ),

            // Key terms chips
            if (msg.keyTerms.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: msg.keyTerms
                      .map((t) => Chip(
                            label: Text(t,
                                style: TextStyle(
                                    fontSize: 11, color: kGoogleBlue)),
                            backgroundColor: kGoogleBlue.withOpacity(0.08),
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ),

            // Section B â€” Diagram
            if (msg.needsDiagram && msg.diagramType != 'none')
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        AppStrings.get('visual_explanation', lang),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: kTextPrimary,
                        ),
                      ),
                    ),
                    DiagramWidget(
                      type: msg.diagramType,
                      description: msg.diagramDescription ?? '',
                    ),
                  ],
                ),
              ),

            // Section C â€” YouTube videos
            if (msg.youtubeResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        AppStrings.get('watch_learn', lang),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: kTextPrimary,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: msg.youtubeResults.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final yt = msg.youtubeResults[i];
                          return _buildYoutubeCard(yt);
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // Section D â€” Action row
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _speak(msg.text),
                    icon: const Icon(Icons.volume_up_rounded, size: 18),
                    label: Text(AppStrings.get('listen', lang),
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: kGoogleBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _simplify(index),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(AppStrings.get('simpler', lang),
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: kGoogleGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
                ],
              ),
            ),
          ).animate()
            .slideY(begin: 0.25, end: 0, duration: 300.ms, curve: Curves.easeOutCubic)
            .fadeIn(duration: 250.ms),
        ),
      ],
    );
  }

  Widget _buildYoutubeCard(Map<String, dynamic> yt) {
    final title = yt['title']?.toString() ?? '';
    final videoId = yt['video_id']?.toString() ?? '';
    final thumbnail = yt['thumbnail']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        final url = 'https://www.youtube.com/watch?v=$videoId';
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: kBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              child: thumbnail.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: thumbnail,
                      height: 70,
                      width: 160,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 70,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.play_circle_outline,
                            color: kTextSecondary),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 70,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.play_circle_outline,
                            color: kTextSecondary),
                      ),
                    )
                  : Container(
                      height: 70,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.play_circle_outline,
                          color: kTextSecondary),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Input Bar ───
  Widget _buildInputBar() {
    final lang = context.watch<LanguageProvider>().language;
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      child: Row(
        children: [
          // Mic button
          GestureDetector(
            onTap: _handleMicTap,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = _isRecording
                    ? 1.0 + _pulseController.value * 0.15
                    : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? kGoogleRed : Colors.transparent,
                      border: Border.all(
                        color: _isRecording ? kGoogleRed : kGoogleBlue,
                        width: 2.5,
                      ),
                      boxShadow: _isRecording
                          ? [
                              BoxShadow(
                                color: kGoogleRed.withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: _isRecording ? Colors.white : kGoogleBlue,
                      size: 26,
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Image picker button
          IconButton(
            onPressed: _handleImagePick,
            icon: Icon(Icons.add_photo_alternate_outlined,
                color: Colors.grey.shade600),
          ),
          const SizedBox(width: 4),

          // Text field
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _textFocus,
              style: TextStyle(fontSize: 15, color: kTextPrimary),
              decoration: InputDecoration(
                hintText: AppStrings.get('type_question', lang),
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: kTextSecondary.withOpacity(0.5),
                ),
                filled: true,
                fillColor: kBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (text) => _sendQuestion(text),
            ),
          ),

          // Send button
          if (_hasText) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _sendQuestion(_textController.text),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: kGoogleBlue,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ).animate().scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: 200.ms,
                  curve: Curves.elasticOut,
                ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Typewriter Text Widget
// ─────────────────────────────────────────────
class _TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const _TypewriterText({required this.text, this.style});
  
  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  String _displayed = '';
  @override
  void initState() {
    super.initState();
    _animate();
  }
  
  void _animate() async {
    for (int i = 0; i <= widget.text.length; i++) {
      if (!mounted) break;
      await Future.delayed(const Duration(milliseconds: 18));
      setState(() => _displayed = widget.text.substring(0, i));
    }
  }
  
  @override
  Widget build(BuildContext context) =>
    Text(_displayed, style: widget.style ?? TextStyle(
      fontSize: 16,
      color: kTextPrimary,
      height: 1.5,
    ));
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.blue.shade50,
          child: const Text('🦉', style: TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8, offset: const Offset(0,2)
            )],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) =>
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: Colors.blue.shade300,
                )
                .animate(onPlay: (c) => c.repeat())
                .scaleXY(
                  begin: 0.5, end: 1.0,
                  delay: Duration(milliseconds: i * 150),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                )
                .then()
                .scaleXY(begin: 1.0, end: 0.5,
                  duration: const Duration(milliseconds: 400)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}



class _SuggestionCard extends StatefulWidget {
  final Suggestion suggestion;
  final VoidCallback onTap;
  final Color categoryColor;
  final int index;
  
  const _SuggestionCard({
    required this.suggestion,
    required this.onTap,
    required this.categoryColor,
    required this.index,
  });

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    final catColor = widget.categoryColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                bottom: 0,
                width: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: catColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.emoji, 
                      style: const TextStyle(
                        fontSize: 36,
                        shadows: [
                          Shadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1C1E),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: catColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// AnimatedBuilder alias for AnimatedWidget pattern
class AnimatedBuilder extends AnimatedWidget {
  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  final Widget Function(BuildContext context, Widget? child) builder;

  @override
  Widget build(BuildContext context) => builder(context, null);
}

// ─────────────────────────────────────────────────────────────────────────────
//  STEP-BY-STEP HOMEWORK CARD
// ─────────────────────────────────────────────────────────────────────────────
class StepByStepCard extends StatefulWidget {
  const StepByStepCard({
    super.key,
    required this.steps,
    required this.finalAnswer,
    this.hint,
  });

  final List<String> steps;
  final String finalAnswer;
  final String? hint;

  @override
  State<StepByStepCard> createState() => _StepByStepCardState();
}

class _StepByStepCardState extends State<StepByStepCard>
    with SingleTickerProviderStateMixin {
  int _currentStep = 1;
  bool _showFinalAnswer = false;
  bool _showHint = false;
  late AnimationController _answerController;
  late Animation<double> _answerScale;

  @override
  void initState() {
    super.initState();
    _answerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _answerScale = CurvedAnimation(
      parent: _answerController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _revealAnswer() {
    setState(() => _showFinalAnswer = true);
    _answerController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = widget.steps.length;
    final progress = _currentStep / totalSteps;
    final stepText = _currentStep <= totalSteps
        ? widget.steps[_currentStep - 1]
        : widget.steps.last;
    final isLastStep = _currentStep >= totalSteps;

    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200, width: 1.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: step counter + progress bar ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Step $_currentStep of $totalSteps',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.blue.shade100,
                    color: const Color(0xFF4285F4),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Step text ──
          Text(
            stepText,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF202124),
              height: 1.5,
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),

          const SizedBox(height: 12),

          // ── Navigation buttons ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_currentStep > 1)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _currentStep--),
                  icon: const Icon(Icons.arrow_back_rounded, size: 15),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4285F4),
                    side: const BorderSide(color: Color(0xFF4285F4), width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    textStyle: const TextStyle(fontSize: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              if (!isLastStep)
                ElevatedButton.icon(
                  onPressed: () => setState(() => _currentStep++),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                  label: const Text('Next Step'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              if (isLastStep && !_showFinalAnswer)
                ElevatedButton.icon(
                  onPressed: _revealAnswer,
                  icon: const Icon(Icons.check_circle_rounded, size: 15),
                  label: const Text('Show Answer ✓'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34A853),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              if (widget.hint != null && !_showHint)
                TextButton.icon(
                  onPressed: () => setState(() => _showHint = true),
                  icon: const Icon(Icons.lightbulb_outline_rounded, size: 14),
                  label: const Text('Hint', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),

          // ── Hint ──
          if (_showHint && widget.hint != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.hint!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
          ],

          // ── Final answer (animated reveal) ──
          if (_showFinalAnswer && widget.finalAnswer.isNotEmpty) ...[
            const SizedBox(height: 12),
            ScaleTransition(
              scale: _answerScale,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF34A853).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF34A853).withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Answer',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF34A853),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.finalAnswer,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF202124),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

