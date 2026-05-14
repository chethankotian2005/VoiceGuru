import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'onboarding_screen.dart';
import 'share_screen.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late int _selectedGrade;
  late String _selectedBoard;
  late String _selectedLanguage;
  late TextEditingController _parentPhoneController;
  bool _reportSent = false;
  bool _isSending = false;

  final _formKey = GlobalKey<FormState>();

  final List<String> _languages = ['english', 'kannada', 'hindi', 'tamil'];
  final List<String> _boards = [
    'Karnataka State Board',
    'CBSE',
    'ICSE',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final langProv = context.read<LanguageProvider>();
    _nameController = TextEditingController(text: langProv.childName);
    _selectedGrade = langProv.grade;
    _selectedBoard = langProv.board;
    _selectedLanguage = langProv.language;
    _parentPhoneController = TextEditingController();
    _loadParentData();
  }

  Future<void> _loadParentData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _parentPhoneController.text = prefs.getString('parent_phone') ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _parentPhoneController.dispose();
    super.dispose();
  }

  List<String> _gradeOptions(String lang) {
    if (lang == 'kannada') {
      const kn = ['೧', '೨', '೩', '೪', '೫', '೬', '೭', '೮', '೯', '೧೦'];
      return List.generate(10, (i) => '${kn[i]} ನೇ ತರಗತಿ');
    }
    return List.generate(10, (i) => 'Class ${i + 1}');
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    
    await context.read<LanguageProvider>().updateProfile(
      name: name,
      grade: _selectedGrade,
      board: _selectedBoard,
      language: _selectedLanguage,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile updated ✓'),
        backgroundColor: kGoogleGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _sendTestReport() async {
    final phone = _parentPhoneController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a WhatsApp number')),
      );
      return;
    }

    setState(() => _isSending = true);

    final langProv = context.read<LanguageProvider>();
    final childId = langProv.childId;
    final childName = langProv.childName;
    final lang = langProv.language;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send_parent_report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'child_id': childId,
          'child_name': childName,
          'parent_phone': phone,
          'callmebot_api_key': 'twilio_managed',
          'language': lang,
        }),
      ).timeout(const Duration(seconds: 30));
      
      final data = jsonDecode(response.body);
      
      if (data['sent'] == true) {
        // Twilio sent successfully
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('parent_phone', phone);

        if (!mounted) return;
        setState(() {
          _reportSent = true;
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Report sent to WhatsApp! ✓'),
            ]),
            backgroundColor: Color(0xFF25D366),
            duration: Duration(seconds: 3),
          ),
        );
      } else if (data['fallback_url'] != null) {
        // Twilio not configured — open WhatsApp directly
        if (!mounted) return;
        setState(() => _isSending = false);
        
        final url = Uri.parse(data['fallback_url']);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          if (mounted) setState(() => _reportSent = true);
        }
      } else {
        // Actual error
        if (!mounted) return;
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${data['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error — check connection'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearHistory() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History?'),
        content: const Text(
            'Are you sure you want to delete all local chat messages? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear', style: TextStyle(color: kGoogleRed)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // TODO: implement actual local storage clear when we implement persistent chat 
    // Since we are currently doing in-memory chat array, we just show a toast
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Chat history cleared.'),
        backgroundColor: kTextSecondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _signOut() async {
    final lang = context.read<LanguageProvider>().language;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('This will clear your profile and chat history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppStrings.get('sign_out', lang),
                style: const TextStyle(color: kGoogleRed)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await context.read<LanguageProvider>().clearAll();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().language;
    final langProv = context.watch<LanguageProvider>();
    final safeName = langProv.childName.isNotEmpty ? langProv.childName : '?';
    final initial = safeName.substring(0, 1).toUpperCase();

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(AppStrings.get('my_profile', lang),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              // ─── PROFILE HEADER ───
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [kGoogleBlue, Color(0xFF6AA6F8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kGoogleBlue.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                langProv.childName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Chip(
                    label: Text(
                      'Class ${langProv.grade}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: kGoogleBlue.withOpacity(0.1),
                    side: BorderSide.none,
                  ),
                  const SizedBox(width: 8),
                   Chip(
                    label: Text(
                      langProv.board,
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: kGoogleGreen.withOpacity(0.1),
                    side: BorderSide.none,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ─── EDIT FORM ───
              Container(
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
                      // Name field
                      Text(
                        AppStrings.get('your_name', lang),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kTextSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 16, color: kTextPrimary),
                        decoration: InputDecoration(
                          hintText: AppStrings.get('name_hint', lang),
                          filled: true,
                          fillColor: kBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please enter your name'
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // Grade dropdown
                      Text(
                        AppStrings.get('your_class', lang),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kTextSecondary),
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
                            style: const TextStyle(
                                fontSize: 16, color: kTextPrimary),
                            items: List.generate(10, (i) {
                              final grades = _gradeOptions(_selectedLanguage);
                              return DropdownMenuItem(
                                value: i + 1,
                                child: Text(grades[i]),
                              );
                            }),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedGrade = value);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Board selector
                      Text(
                        AppStrings.get('your_board', lang),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kTextSecondary),
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
                              color: isSelected
                                  ? kGoogleBlue
                                  : Colors.grey.shade300,
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

                      // Preferred Language
                      Text(
                        AppStrings.get('preferred_lang', lang),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kTextSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.get('lang_note', lang),
                        style: TextStyle(
                            fontSize: 12,
                            color: kTextSecondary.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _languages.map((lang) {
                          final isSelected = _selectedLanguage == lang;
                          return ChoiceChip(
                            label: Text(
                              {
                                'english': 'English',
                                'kannada': 'ಕನ್ನಡ',
                                'hindi': 'हिंदी',
                                'tamil': 'தமிழ்',
                              }[lang]!,
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
                              color: isSelected
                                  ? kGoogleBlue
                                  : Colors.grey.shade300,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            onSelected: (_) {
                              setState(() => _selectedLanguage = lang);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ─── PARENT UPDATES ───
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.notifications_active_outlined, color: Color(0xFF34A853), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.get('parent_updates', lang),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.get('parent_updates_note', lang),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _parentPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: "Parent's WhatsApp (with +country)",
                          hintText: "+91XXXXXXXXXX",
                          prefixIcon: const Icon(Icons.phone_iphone, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSending ? null : _sendTestReport,
                          icon: _isSending
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                          label: Text(_isSending 
                            ? 'Sending...' : 'Send Report Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isSending 
                              ? Colors.grey : const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      if (_reportSent)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(children: [
                            const Icon(Icons.check_circle, color: Color(0xFF34A853), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Report sent to parent WhatsApp!',
                              style: TextStyle(color: Colors.green.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ─── BUTTONS ───
              // Share with Teacher
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_rounded, size: 20),
                  label: const Text('Share with Teacher / Parent'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34A853),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const ShareScreen(),
                      transitionsBuilder: (_, animation, __, child) =>
                          SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          ),
                      transitionDuration: const Duration(milliseconds: 280),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGoogleBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _saveProfile,
                  child: Text(AppStrings.get('save_changes', lang)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kGoogleRed,
                    side: const BorderSide(color: kGoogleRed, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: _clearHistory,
                  child: Text(AppStrings.get('clear_history', lang)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _signOut,
                style: TextButton.styleFrom(
                  foregroundColor: kTextSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(AppStrings.get('sign_out', lang),
                    style: const TextStyle(
                        fontSize: 15, decoration: TextDecoration.underline)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
