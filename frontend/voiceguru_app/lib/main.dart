import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/chat_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_service.dart' show baseUrl;

import 'package:provider/provider.dart';
import 'providers/language_provider.dart';
import 'providers/streak_provider.dart';
import 'l10n/app_strings.dart';

// --------------- Backend URL ---------------
String get backendBaseUrl => baseUrl;

// --------------- Google Colors ---------------
const Color kGoogleBlue = Color(0xFF4285F4);
const Color kGoogleGreen = Color(0xFF34A853);
const Color kGoogleYellow = Color(0xFFFBBC05);
const Color kGoogleRed = Color(0xFFEA4335);
const Color kBackground = Color(0xFFF8F9FA);
const Color kSurface = Color(0xFFFFFFFF);
const Color kDarkSurface = Color(0xFF1A1A2E);
const Color kTextPrimary = Color(0xFF202124);
const Color kTextSecondary = Color(0xFF5F6368);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final langProvider = LanguageProvider();
  await langProvider.loadFromPrefs();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: langProvider),
        ChangeNotifierProvider(create: (_) => StreakProvider()),
      ],
      child: const VoiceGuruApp(),
    ),
  );
}

class VoiceGuruApp extends StatelessWidget {
  const VoiceGuruApp({super.key});

  @override
  Widget build(BuildContext context) {
    final langProv = context.watch<LanguageProvider>();
    final hasProfile = langProv.childName.isNotEmpty;

    return MaterialApp(
      title: AppStrings.get('app_title', langProv.language),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kGoogleBlue,
        brightness: Brightness.light,
        scaffoldBackgroundColor: kBackground,
        textTheme: ThemeData.light().textTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: kSurface,
          foregroundColor: kTextPrimary,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
      ),
      home: hasProfile 
          ? ChatScreen(
              backendBaseUrl: backendBaseUrl,
              childId: langProv.childId,
              isGuest: false,
            )
          : const OnboardingScreen(),
    );
  }
}
