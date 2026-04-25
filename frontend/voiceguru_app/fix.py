import os

filepath = r'D:\VoiceGuru\frontend\voiceguru_app\lib\screens\chat_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Imports
text = text.replace("import '../services/api_service.dart';", "import '../services/api_service.dart';\nimport '../models/voiceguru_models.dart';")

# 2. Add local vars to _ChatScreenState
old_vars = '''  final List<ChatMessage> _messages = [];
  HotwordState _hotwordState = HotwordState.idle;'''

new_vars = '''  final List<ChatMessage> _messages = [];
  List<Suggestion> _suggestions = [];
  bool _isSuggestionsLoading = true;
  HotwordState _hotwordState = HotwordState.idle;'''

text = text.replace(old_vars, new_vars)

# 3. Add _loadSuggestions
old_init = '''  @override
  void initState() {'''
new_init = '''  Future<void> _loadSuggestions() async {
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
  void initState() {'''
text = text.replace(old_init, new_init)

# 4. Remove fake Welcome message and trigger _loadSuggestions
old_welcome = '''    // Add welcome message
    _messages.add(ChatMessage(
      sender: MessageSender.ai,
      text: widget.isGuest
          ? "Hello! I'm VoiceGuru\\nAsk me anything - tap the mic or type below!"
          : "Hello ${context.read<LanguageProvider>().childName}! I'm VoiceGuru\\nWhat would you like to learn today?",
    ));
  }'''

new_welcome = '''    _loadSuggestions();
  }'''
text = text.replace(old_welcome, new_welcome)

# 5. Build method replacement for body
old_list = '''          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  _buildMessage(_messages[index], index),
            ),
          ),'''

new_list = '''          // Chat messages
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
          ),'''
text = text.replace(old_list, new_list)

# 6. Add Grid methods
grid_methods = '''  String _getGreeting() {
    final hour = DateTime.now().hour;
    final lang = context.watch<LanguageProvider>().language;
    final name = context.watch<LanguageProvider>().childName;
    
    final String fallback = name.isEmpty ? 'Friend' : name;
    
    if (hour >= 5 && hour < 12) {
      if (lang == 'kannada') return 'ಶುಭ ಮುಂಜಾನೆ $fallback! 🌅';
      if (lang == 'hindi') return 'सुप्रभात $fallback! 🌅';
      if (lang == 'tamil') return 'காலை வணக்கம் $fallback! 🌅';
      return 'Good morning $fallback! 🌅';
    } else if (hour >= 12 && hour < 17) {
      if (lang == 'kannada') return 'ಶುಭ ಮಧ್ಯಾಹ್ನ $fallback! ☀️';
      if (lang == 'hindi') return 'शुभ दोपहर $fallback! ☀️';
      if (lang == 'tamil') return 'மதிய வணக்கம் $fallback! ☀️';
      return 'Good afternoon $fallback! ☀️';
    } else if (hour >= 17 && hour < 21) {
      if (lang == 'kannada') return 'ಶುಭ ಸಂಜೆ $fallback! 🌙';
      if (lang == 'hindi') return 'शुभ संध्या $fallback! 🌙';
      if (lang == 'tamil') return 'மாலை வணக்கம் $fallback! 🌙';
      return 'Good evening $fallback! 🌙';
    } else {
      if (lang == 'kannada') return 'ಕಲಿಯಲು ಸಿದ್ಧರಿದ್ದೀರಾ? 🦉';
      if (lang == 'hindi') return 'सीखने के लिए तैयार हैं? 🦉';
      if (lang == 'tamil') return 'கற்க தயாரா? 🦉';
      return 'Ready to learn? 🦉';
    }
  }

  String _getSuggestionSubtitle() {
    final lang = context.watch<LanguageProvider>().language;
    if (lang == 'kannada') return 'ಇಂದು ನೀವು ಏನನ್ನು ಅನ್ವೇಷಿಸಲು ಬಯಸುತ್ತೀರಿ?';
    if (lang == 'hindi') return 'आज आप क्या एक्सप्लोर करना चाहेंगे?';
    if (lang == 'tamil') return 'இன்று நீங்கள் எதை ஆராய விரும்புகிறீர்கள்?';
    return 'What would you like to explore today?';
  }

  Color _getCategoryColor(String category) {
    if (category == 'curriculum') return const Color(0xFF4285F4); // Google Blue
    if (category == 'curiosity') return const Color(0xFF34A853); // Google Green
    return const Color(0xFFFBBC05); // Google Yellow
  }

  Widget _buildSuggestionsGrid() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _getGreeting(),
                  style: const TextStyle(
                    fontSize: 24,
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
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text(
            _getSuggestionSubtitle(),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.2),
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
                childAspectRatio: 0.85,
              ),
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final s = _suggestions[index];
                final catColor = _getCategoryColor(s.category);
                
                return GestureDetector(
                  onTap: () {
                    _textController.text = s.query;
                    _handleSendText();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: catColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.emoji, style: const TextStyle(fontSize: 32)),
                        const Spacer(),
                        Text(
                          s.text,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF202124),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.15),
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
                      ],
                    ),
                  ),
                ).animate()
                 .fadeIn(delay: Duration(milliseconds: 200 + (index * 50)))
                 .slideY(begin: 0.2);
              },
            ),
        ],
      ),
    );
  }'''

text = text.replace('  // ─── App Bar ───', grid_methods + '\n\n  // ─── App Bar ───')

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(text)

print('Success!')
