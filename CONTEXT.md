# VoiceGuru Build Context

Last Updated: 2026-04-25T11:42:00+05:30

## Project Overview
VoiceGuru is a voice-first AI tutoring app for Karnataka State Board students.
Current workspace root is `D:\VoiceGuru` with:
- FastAPI backend for ask, simplify, history, speech synthesis, transcription, and YouTube search.
- Gemini-based classifier, explainer, and simplifier agents returning structured JSON.
- Firestore logging and history retrieval.
- Flutter frontend app built with Google Material Design 3, focusing on a child-friendly, interactive chat UI.
- Highly gamified experience with dynamic daily quizzes, haptic feedback, sound effects, level progression, and an interactive learning mascot.

## Current Folder Structure
- `backend/`
  - `agents/`
    - `classifier_agent.py`
    - `explainer_agent.py`
    - `simplifier_agent.py`
    - `__init__.py`
  - `firebase_logger.py`
  - `pipeline.py`
  - `syllabus_context.py`
  - `main.py`
  - `.env`
  - `.env.example`
  - `requirements.txt`
- `frontend/voiceguru_app/`
  - `lib/main.dart`
  - `lib/models/voiceguru_models.dart`
  - `lib/models/progress_data.dart`
  - `lib/providers/language_provider.dart`
  - `lib/providers/streak_provider.dart`
  - `lib/screens/onboarding_screen.dart`
  - `lib/screens/chat_screen.dart`
  - `lib/screens/history_screen.dart`
  - `lib/screens/progress_screen.dart`
  - `lib/services/api_service.dart`
  - `lib/services/hotword_service.dart`
  - `lib/services/tts_service.dart`
  - `lib/services/voice_service.dart`
  - `lib/services/voiceguru_api.dart`
  - `lib/widgets/diagram_widget.dart`
  - `lib/widgets/xp_toast.dart`
  - `lib/widgets/level_badge.dart`
  - `lib/widgets/owl_reactions.dart`

## Backend API (Current)

### POST /ask
Input:
- `text`
- `language` (`kannada|hindi|tamil|english`)
- `grade`
- `child_id`

Output:
- `explanation`
- `subject`
- `grade_used`
- `language`
- `agent_trace`
- `needs_diagram` (boolean)
- `diagram_description` (string | null)
- `diagram_type` (string)
- `youtube_search_query` (string | null)
- `key_terms` (list of strings)

Implementation:
- Calls async `run_voiceguru_pipeline(...)`
- Explainer returns structured JSON instead of string.
- Fire-and-forget logs to Firestore via `log_question(...)`
- Returns safe fallback payload on errors

### POST /simplify
Input:
- `original_question`
- `original_explanation`
- `language`
- `grade`
- `child_id`

Output:
- `simplified_explanation`

Implementation:
- Calls async `run_simplify_pipeline(...)`
- Fire-and-forget logs simplified text to Firestore
- Returns safe fallback text on errors

### GET /speak
Query:
- `text`
- `language`

Output:
- `audio_base64`
- `language`

Implementation:
- Uses Google Cloud Text-to-Speech
- Returns base64 MP3 payload for frontend playback
- Returns empty audio on missing text or runtime failure

### POST /transcribe
Input:
- `audio_base64`
- `language`

Output:
- `text`
- `is_hotword` (boolean)
- `hotword_detected` (string | null)

Implementation:
- Uses Google Cloud Speech-to-Text
- Identifies predefined hotwords (e.g., "Hey VoiceGuru") across multiple languages for continuous listening.

### GET /youtube_search
Query:
- `query`
- `grade` (optional, defaults to 6)
- `max_results` (default 3)

Output:
- `results`: List of video dictionaries (`title`, `video_id`, `thumbnail`, `channel`)

Implementation:
- Curates educational content using YouTube Data API v3 and curated educational channel whitelists.
- Dynamically reranks results based on grade, preferring grade-specific channels/titles and penalizing babyish content for older students.

### GET /progress/{child_id}
Output:
- JSON with `streak_days`, `total_questions`, `today_questions`, `daily_goal`, `weekly_data`, `monthly_data`, `subject_breakdown`, `badges`.

Implementation:
- Aggregates the Firestore `questions` collection to calculate a gamified learning progress dashboard, streaks, and subject mastery badges.

### GET /history/{child_id}
Implementation:
- Calls async `get_child_history(child_id)`
- Returns up to 20 latest entries
- Falls back to empty list on errors

### GET /status
Output:
- `{"status": "ok", "gemini": "connected"}` when `GEMINI_API_KEY` is set
- `{"status": "ok", "gemini": "not_configured"}` otherwise

## Backend Components

### main.py
- FastAPI app with permissive CORS
- Async ask/simplify/speak/transcribe/youtube_search/history routes and status route
- Fire-and-forget logging helper for Firestore

### pipeline.py
- `run_voiceguru_pipeline(...)` flow:
  - classify question
  - pick grade/language
  - fetch syllabus context
  - generate explanation (structured output)
  - map structured data through pipeline
- `run_simplify_pipeline(...)` flow:
  - simplify prior explanation
- Standardized safe fallback payloads

### agents/classifier_agent.py
- Gemini-backed classifier using the new `google-genai` (V2) SDK.
- Returns normalized `subject`, `estimated_grade`, `complexity`, `detected_language`.
- Uses JSON parsing and safe defaults
- Current model: `gemini-2.5-flash-lite`

### agents/explainer_agent.py
- Gemini-backed explainer using the `google-genai` SDK returning strong, structured JSON using dynamic prompt.
- Includes `needs_diagram`, `diagram_type`, `youtube_search_query` (with dynamic grade-aware keyword appending).
- Grade-aware, language-aware, Karnataka-context explanations
- Current model: `gemini-2.5-flash-lite`

### agents/simplifier_agent.py
- Gemini-backed simplifier (direct model call)
- Uses strict simplification rules (short, clear, child-friendly)
- Current model: `gemini-2.5-flash-lite`

### syllabus_context.py
- Karnataka State Board context map for grades 5-8

### firebase_logger.py
- Firestore integration via `firebase-admin`
- Timestamp-like values serialized to ISO for frontend compatibility

## Environment and Dependencies

### backend/.env keys
- `GEMINI_API_KEY`
- `GOOGLE_APPLICATION_CREDENTIALS`
- `YOUTUBE_API_KEY`

### backend/requirements.txt
- `fastapi`
- `uvicorn`
- `google-genai`
- `google-cloud-texttospeech`
- `google-cloud-speech`
- `firebase-admin`
- `python-dotenv`
- `httpx`
- `cachetools`

## Flutter App (Current)

### pubspec.yaml
- Added dependencies: `provider` (Global State), `flutter_animate` (Micro-interaction & Streaming text UI), `google_fonts` (Nunito), `url_launcher`, `cached_network_image`, `speech_to_text`, `just_audio`, `shared_preferences`, `http`, `confetti`.

### providers/language_provider.dart
- Global `ChangeNotifier` managing `childName`, `grade`, `board`, and `language` synchronously.
- Eliminates async constructor boilerplate and triggers deep reactive UI rebuilds globally.

### providers/streak_provider.dart
- Manages `ProgressData` state, fetching it from `/progress` and triggering global streak confetti animations via `streakJustIncreased`.

### main.dart
- Entrypoint wrapped in `ChangeNotifierProvider`.
- Decouples routing and deeply injects `LanguageProvider` profile across widget sub-trees.
- Uses `context.watch<LanguageProvider>().childName.isEmpty` for synchronous setup redirection.

### screens/onboarding_screen.dart
- High-end Material 3 multi-language selector and student profile setup.
- Interacts with `LanguageProvider.updateProfile()` globally rather than fragmenting local storage logic.

### screens/chat_screen.dart
- Rebuilt exactly to Gemini UI standards: Flat corners on chat bubbles, dynamic `_ThinkingBubble` with bouncy `flutter_animate` `🦉` dot loaders.
- Uses `_TypewriterText` character-by-character async streamer instead of relying on `Timer.periodic`.
- Dynamically watches `LanguageProvider` state for personalized avatar and language mappings during real-time typing/speech toggles.
- Displays full-screen interactive overlays using `InteractiveViewer` directly from diagram elements.

### screens/profile_screen.dart
- Clean Material UI referencing `context.read<LanguageProvider>()` to map existing values and `updateProfile()` to write.
- Seamlessly re-syncs global state preventing hot-reload caching bugs when migrating preferences.

### screens/progress_screen.dart
- Material 3 gamified dashboard showing streaks, bar charts (Weekly/Monthly), horizontal subject bars, and a grid of unlocked achievement badges.

### widgets/diagram_widget.dart
- Renders multiple diagram types (`ray_diagram`, `food_chain`, `circuit`, etc.) visually inline based on backend directions.
- Now wraps complex custom painters inside an `InteractiveViewer` pop-up dialog, allowing pinch-to-zoom capabilities.

### widgets/xp_toast.dart, level_badge.dart, owl_reactions.dart
- `XPToast`: Micro-interaction component popping +10 XP notifications when responses arrive.
- `LevelBadge`: Calculates and displays user levels (Sprout to Master) based on total questions asked.
- `MascotWidget`: Renders animated states (thinking, bouncy, happy, idle wave) for student's chosen learning buddy.

### services/api_service.dart
- Updated methods: `askQuestion(...)`, `simplify(...)`, `youtubeSearch(...)`, `getHistory(childId)`.
- Handles new structured JSON responses with safe fallback payloads on network/runtime errors.

### services/tts_service.dart
- Primary: Calls backend `/speak` and plays returned MP3 using `just_audio` and temporary files for reliable Android playback.
- Fallback: Uses `flutter_tts` when backend requests fail.

### services/voice_service.dart
- `speech_to_text` dynamically ingests variables natively pulling localized values via `chat_screen.dart` initialization loops securely mapping to Kannada, Hindi, and Tamil models.

## Run Commands

### Backend
1. `cd backend`
2. `pip install -r requirements.txt`
3. `uvicorn main:app --reload --port 8000`

### Flutter Frontend
1. `cd frontend/voiceguru_app`
2. `flutter run` (or `flutter run -d chrome`)

## Notes
- Live `/ask` and `/speak` were validated with HTTP 200 responses.
- Explainer pipeline strictly enforces ENUM types to prevent hallucinatory shapes (restricting to predefined geometries).
- App prioritizes Google Material 3 UI design paradigms, using `flutter_animate` extensively.

## Recent Frontend Polish Updates (Chat Screen)
- **Welcome Message**: Implemented a one-time animated welcome greeting ('Hello {name}! I'm VoiceGuru...') using nimated_text_kit and lutter_animate that displays when the chat is first opened in a session.
- **Subject-aware AppBar Color**: The chat AppBar dynamically transitions its background tint based on the subject of the AI's response (Math = Blue, Science = Green, Social Studies = Amber, General = Blue) using AnimatedContainer with a 500ms duration for a polished, responsive feel.
- **Localization Support**: Added welcome_study_buddy strings to pp_strings.dart for English, Kannada, Hindi, and Tamil.
