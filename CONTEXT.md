# VoiceGuru Build Context

Last Updated: 2026-04-26T02:05:00+05:30

## Project Overview
VoiceGuru is a voice-first AI tutoring app for Karnataka State Board students, designed to provide a personalized, multi-child learning experience.
- **Backend**: FastAPI (Python) hosting AI agents, progress analytics, and deployment on Render.
- **AI Agents**: Gemini-based (google-genai V2) Classifier, Explainer (with Homework Solver), and Simplifier agents.
- **Database**: Firestore with a multi-child architecture (segmented by `child_id`).
- **Frontend**: Flutter (Material 3) with a highly animated, gamified UI and localized support.

## Current Folder Structure
- `backend/`
  - `agents/` (Classifier, Explainer/Solver, Simplifier, Quiz)
  - `firebase_logger.py` (Multi-child Firestore logic & Analytics)
  - `pipeline.py` (Orchestration)
  - `syllabus_context.py` (Karnataka Board Mapping)
  - `main.py` (API Endpoints & Deployment Config)
  - `Procfile` (Render Start Command)
  - `requirements.txt`
- `frontend/voiceguru_app/`
  - `lib/providers/` (Language & Streak state)
  - `lib/screens/` (Onboarding, Chat, History, Progress, Profile, Quiz)
  - `lib/services/` (API, TTS, Voice/STT)
  - `lib/widgets/` (Streak Banner, Diagram, Mascot, XP Toast)

## Backend API (Current)

### 👤 User Management
- **POST /create_user**: Persists child profile metadata (Name, Grade, Board, Mascot) to the `users` collection.
- **Integration**: Called immediately after the frontend onboarding flow.

### 📚 AI Tutoring & Homework
- **POST /ask**: Standard text-based tutor response.
- **POST /ask_image**: Enhanced Homework Solver. Returns `explanation`, `steps` (list), `final_answer`, and `hint`.
- **POST /simplify**: Simplifies complex explanations for younger students.

### 📊 Progress & Dashboard
- **GET /progress/{child_id}**: Aggregates streaks, badges, and subject breakdown.
- **GET /dashboard/{child_id}**: High-level JSON for teacher/parent view.
- **GET /dashboard/{child_id}/report**: Gemini-generated weekly learning report (HTML).
- **Integration**: Backend automatically identifies profiles via the `users` collection.

### 🎙️ Audio & Vision
- **POST /transcribe**: STT with multilingual hotword detection ("Hey VoiceGuru").
- **GET /speak**: Google Cloud TTS (Wavenet) synthesis.
- **GET /youtube_search**: Grade-curated educational video search.

## Backend Deployment (Render)
- **Repo**: Pushed to GitHub (`main` branch).
- **Security**: `.gitignore` protects `.env` and sensitive JSON keys.
- **Cloud Config**:
  - **Root Directory**: `backend`
  - **Secret Files**: Supports `voiceguru-credentials.json`.
  - **Env Vars**: `GOOGLE_APPLICATION_CREDENTIALS` can now take the **raw JSON content** directly for easier setup.

## Flutter App (Polish & UX)

### 🎨 Visual Excellence
- **Page Transitions**: All navigation uses a custom `SlideTransition` (Slide from right, easeOutCubic).
- **Message Animations**: Message bubbles slide up and fade in (`.slideY` + `.fadeIn`).
- **Dynamic Theming**: AppBar color shifts based on the subject of the AI's response.
- **Mascot**: Removed overlapping UI elements; mascot reactions are now integrated into the chat flow.

### 🎮 Gamification
- **Streak System**: Duolingo-style animated flame banner and motivational streaks.
- **Dynamic Quizzes**: Generated based on today's learning topics after 3 questions are asked.
- **Leveling**: Progresses from "Sprout" to "Master" based on XP (questions asked).

### 🛠️ Services & Logic
- **API Service**: Standardized to use `https://voiceguru-backend.onrender.com` (Cloud) or `10.x.x.x` (Local).
- **Audio**: Success "beeps" removed for a more premium, quiet experience.
- **Offline Fallbacks**: Local TTS and basic error handling ensure the app doesn't crash on network failure.

## Environment and Dependencies
- **Backend**: `fastapi`, `uvicorn`, `google-genai`, `firebase-admin`, `google-cloud-texttospeech`, `google-cloud-speech`.
- **Frontend**: `provider`, `flutter_animate`, `just_audio`, `speech_to_text`, `confetti`, `animated_text_kit`.

## Notes
- Deployment on Render is verified and live.
- Firebase connection supports raw JSON env vars to bypass path-resolution issues on cloud hosts.
- Multi-child data isolation is strictly enforced via the `child_id` discriminator in all Firestore queries.
