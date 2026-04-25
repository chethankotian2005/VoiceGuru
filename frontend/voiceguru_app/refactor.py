import os

base = r'D:\VoiceGuru\frontend\voiceguru_app\lib'

# 1. chat_screen.dart
chat_path = os.path.join(base, 'screens', 'chat_screen.dart')
with open(chat_path, 'r', encoding='utf-8') as f:
    chat_content = f.read()

# Make sure provider is imported
if "import 'package:provider/provider.dart';" not in chat_content:
    chat_content = chat_content.replace(
        "import 'profile_screen.dart';",
        "import 'profile_screen.dart';\nimport 'package:provider/provider.dart';\nimport '../providers/language_provider.dart';"
    )

chat_content = chat_content.replace("widget.language", "context.read<LanguageProvider>().language")
chat_content = chat_content.replace("widget.childName", "context.read<LanguageProvider>().childName")
chat_content = chat_content.replace("widget.grade", "context.read<LanguageProvider>().grade")

# Also at top of build we can use watch for UI elements
chat_content = chat_content.replace("context.read<LanguageProvider>().childName", "context.watch<LanguageProvider>().childName")
# For _speakingLanguage tracking in initState, we should NOT use context.read if not available inside initState safely unless we use Builder or late init.
# But replacing `widget.language` inside initState is okay with context.read if listen: false. 
# Revert that for initState:
chat_content = chat_content.replace("_speakingLanguage = context.watch<LanguageProvider>().language;", "_speakingLanguage = context.read<LanguageProvider>().language;")

with open(chat_path, 'w', encoding='utf-8') as f:
    f.write(chat_content)

# 2. profile_screen.dart
prof_path = os.path.join(base, 'screens', 'profile_screen.dart')
with open(prof_path, 'r', encoding='utf-8') as f:
    prof_content = f.read()

if "import 'package:provider/provider.dart';" not in prof_content:
    prof_content = prof_content.replace(
        "import '../main.dart';",
        "import '../main.dart';\nimport 'package:provider/provider.dart';\nimport '../providers/language_provider.dart';"
    )

# Instead of prefs inside _saveProfile
old_save = """    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('child_name', _nameController.text.trim());
    await prefs.setInt('grade', _selectedGrade);
    await prefs.setString('board', _selectedBoard);
    await prefs.setString('language', _selectedLanguage);"""

new_save = """    context.read<LanguageProvider>().updateProfile(
      name: _nameController.text.trim(),
      grade: _selectedGrade,
      board: _selectedBoard,
      language: _selectedLanguage,
    );"""

prof_content = prof_content.replace(old_save, new_save)

# Replace prefs load
old_load = """    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('child_name') ?? '';
      _selectedGrade = prefs.getInt('grade') ?? 6;
      _selectedBoard = prefs.getString('board') ?? _boards.first;
      _selectedLanguage = prefs.getString('language') ?? 'english';
    });"""

new_load = """    final langProv = context.read<LanguageProvider>();
    setState(() {
      _nameController.text = langProv.childName;
      _selectedGrade = langProv.grade;
      _selectedBoard = langProv.board;
      _selectedLanguage = langProv.language;
    });"""

prof_content = prof_content.replace(old_load, new_load)

# Clear history
old_clear = """    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();"""

new_clear = """    await context.read<LanguageProvider>().clearAll();"""

prof_content = prof_content.replace(old_clear, new_clear)

with open(prof_path, 'w', encoding='utf-8') as f:
    f.write(prof_content)

# 3. onboarding_screen.dart
onb_path = os.path.join(base, 'screens', 'onboarding_screen.dart')
with open(onb_path, 'r', encoding='utf-8') as f:
    onb_content = f.read()

if "import 'package:provider/provider.dart';" not in onb_content:
    onb_content = onb_content.replace(
        "import 'chat_screen.dart';",
        "import 'chat_screen.dart';\nimport 'package:provider/provider.dart';\nimport '../providers/language_provider.dart';"
    )

old_finish = """    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('child_name', name);
    await prefs.setInt('grade', _selectedGrade);
    await prefs.setString('board', _selectedBoard);
    await prefs.setString('language', _selectedLanguage);"""

new_finish = """    context.read<LanguageProvider>().updateProfile(
      name: name,
      grade: _selectedGrade,
      board: _selectedBoard,
      language: _selectedLanguage,
    );"""

onb_content = onb_content.replace(old_finish, new_finish)

with open(onb_path, 'w', encoding='utf-8') as f:
    f.write(onb_content)

print("Phase 1 done")
