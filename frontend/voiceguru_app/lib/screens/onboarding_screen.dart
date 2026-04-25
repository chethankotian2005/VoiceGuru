import 'dart:math';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'chat_screen.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';

const List<String> _languages = ['english', 'kannada', 'hindi', 'tamil'];
const List<String> _languageLabels = ['English', 'ಕನ್ನಡ', 'हिंदी', 'தமிழ்'];

const List<String> _boards = [
  'Karnataka State Board',
  'CBSE',
  'ICSE',
  'Other',
];

List<String> _gradeOptions(String lang) {
  if (lang == 'kannada') {
    const kn = ['೧', '೨', '೩', '೪', '೫', '೬', '೭', '೮', '೯', '೧೦'];
    return List.generate(10, (i) => '${kn[i]} ನೇ ತರಗತಿ');
  }
  return List.generate(10, (i) => 'Class ${i + 1}');
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  int _selectedGrade = 6;
  String _selectedBoard = 'Karnataka State Board';
  String _selectedMascot = 'owl';
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveAndNavigate({bool guest = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final childId =
        'child_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

    if (guest) {
      await prefs.setString('voiceguru_child_id', childId);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            backendBaseUrl: backendBaseUrl,
            childId: childId,
            isGuest: true,
          ),
        ),
        (_) => false,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final langProv = context.read<LanguageProvider>();
    await langProv.updateProfile(
      name: _nameController.text.trim(),
      grade: _selectedGrade,
      board: _selectedBoard,
      language: langProv.language,
      mascot: _selectedMascot,
    );

    // Also inject child ID manually for API
    await prefs.setString('voiceguru_child_id', childId);

    // Call backend to create user
    try {
      final apiService = ApiService(baseUrl: backendBaseUrl);
      await apiService.createUser(
        childId: childId,
        name: _nameController.text.trim(),
        grade: _selectedGrade,
        board: _selectedBoard,
        language: langProv.language,
        mascot: _selectedMascot,
      );
    } catch (e) {
      debugPrint('Failed to create user on backend: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          backendBaseUrl: backendBaseUrl,
          childId: childId,
          isGuest: false,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── Hero Section ───
            _buildHero(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // ─── Language Selector ───
                  _buildLanguageSelector(),
                  const SizedBox(height: 32),

                  // ─── Form Card ───
                  _buildFormCard(),
                  const SizedBox(height: 16),

                  // ─── Buttons ───
                  _buildButtons(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    final lang = context.watch<LanguageProvider>().language;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_languages.length, (i) {
          final isActive = lang == _languages[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                _languageLabels[i],
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isActive ? Colors.white : kGoogleBlue,
                ),
              ),
              selected: isActive,
              selectedColor: kGoogleBlue,
              backgroundColor: kSurface,
              side: const BorderSide(color: kGoogleBlue, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (_) {
                context.read<LanguageProvider>().updateLanguage(_languages[i]);
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHero() {
    final lang = context.watch<LanguageProvider>().language;
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4285F4), Color(0xFF34A853)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🦉', style: TextStyle(fontSize: 52))
                .animate()
                .scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 12),
              Text(AppStrings.get('welcome', lang),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 24, 
                  fontWeight: FontWeight.bold
                )
              ),
              Text(AppStrings.get('your_tutor', lang),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14)
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    final lang = context.watch<LanguageProvider>().language;
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Name field ───
            Text(
              AppStrings.get('your_name', lang),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              style: TextStyle(fontSize: 16, color: kTextPrimary),
              decoration: InputDecoration(
                hintText: AppStrings.get('name_hint', lang),
                hintStyle: TextStyle(color: kTextSecondary.withOpacity(0.5)),
                filled: true,
                fillColor: kBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppStrings.get('name_error', lang);
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ─── Grade dropdown ───
            Text(
              AppStrings.get('your_class', lang),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedGrade,
                  isExpanded: true,
                  style: TextStyle(fontSize: 16, color: kTextPrimary),
                  items: List.generate(10, (i) {
                    final grades = _gradeOptions(lang);
                    return DropdownMenuItem(
                      value: i + 1,
                      child: Text(grades[i]),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedGrade = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ─── Board selector ───
            Text(
              AppStrings.get('your_board', lang),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _boards.map((board) {
                final isSelected = _selectedBoard == board;
                return ChoiceChip(
                  label: Text(
                    board,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : kTextPrimary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: kGoogleBlue,
                  backgroundColor: kBackground,
                  side: BorderSide(
                    color: isSelected ? kGoogleBlue : Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (_) {
                    setState(() => _selectedBoard = board);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ─── Mascot selector ───
            Text(
              'Choose your study buddy!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMascotOption('owl', '🦉', 'Ollie'),
                _buildMascotOption('finn', '🐬', 'Finn'),
                _buildMascotOption('leo', '🦁', 'Leo'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMascotOption(String id, String emoji, String name) {
    final isSelected = _selectedMascot == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedMascot = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? kGoogleBlue.withValues(alpha: 0.1) : kBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? kGoogleBlue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? kGoogleBlue : kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtons() {
    final lang = context.watch<LanguageProvider>().language;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kGoogleBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
              textStyle: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => _saveAndNavigate(),
            child: Text(AppStrings.get('start_learning', lang)),
          ),
        ),
        const SizedBox(height: 12),
        // Skip link
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _saveAndNavigate(guest: true),
            child: Text(
              AppStrings.get('skip', lang),
              style: TextStyle(
                fontSize: 14,
                color: kTextSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}


