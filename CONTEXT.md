# VoiceGuru Build Context

Last Updated: 2026-04-26

## Project Overview
VoiceGuru is a state-of-the-art, voice-first AI tutoring platform designed for State Board and CBSE students. It delivers a hyper-personalized, adaptive, and highly animated learning experience with multi-child support.

- **Backend**: FastAPI (Python) hosting adaptive AI agents, automated reporting systems, and deployment on Render.
- **AI Agents**: Gemini-based (`google-genai` V2) Classifier, Explainer, Simplifier, and Quiz agents.
- **Database**: Firestore (cloud) with a multi-child architecture, and SQLite (local) for offline caching.
- **Frontend**: Flutter (Material 3) with dynamic gamification, offline resilience, and multilingual support.

## Key System Architectures

### 🧠 Adaptive Difficulty Engine
- VoiceGuru is the ONLY AI tutor that automatically scales explanation complexity based on performance.
- Evaluates recent quiz scores to classify the student as `easy`, `medium`, or `hard`.
- Dynamically injects specialized teaching strategies into the Gemini Explainer prompt (e.g., "Break into tiny steps" vs "Challenge with advanced concepts").
- Surfaces difficulty badges dynamically in the Flutter AppBar (`Building foundations 🌱`, `Advanced learner 🚀`).

### 📴 Smart Library (Offline Mode)
- **Connectivity Monitoring**: Continuously monitors network state via `connectivity_plus`.
- **Silent Caching**: Automatically saves all successful online AI explanations to a local SQLite database using `sqflite`.
- **Local Inference**: When offline, the app searches the local `Smart Library` cache via keyword matching to provide instant, "cached" AI answers without a connection.

### 📱 Twilio WhatsApp Reporting
- Automatically generates rich, weekly progress summaries for parents using Gemini.
- Integrates the **Twilio SDK** to send formatted WhatsApp messages containing streak info, subject breakdowns, and a web dashboard link.
- Endpoints: `POST /send_parent_report` and `POST /trigger_weekly_reports`.

### 📚 Dynamic Syllabus & Conversational Memory
- **Dynamic Context**: Replaced static chapter lists with an on-the-fly Gemini curriculum fetcher that generates board-specific (NCERT/KSEEB) context and caches it for performance.
- **Memory**: Maintains a rolling context window (last 10 exchanges) per child in memory, allowing students to ask contextual follow-ups like "Why?" or refer to "that topic".

### 🎙️ Human-like TTS & Vision
- **Warm TTS**: Google Cloud TTS upgraded with SSML to deliver a warm, human, emotional voice (prosody adjustments: `rate="90%"`, `pitch="+1.5st"`).
- **Vision Solver**: `POST /ask_image` provides step-by-step homework guidance without giving away the final answer immediately.

## Current Folder Structure
- `backend/`
  - `agents/` (Classifier, Explainer/Solver, Simplifier, Quiz)
  - `firebase_logger.py` (Multi-child Firestore logic, Analytics & Deduplication)
  - `pipeline.py` (Orchestration & Context passing)
  - `syllabus_context.py` (Dynamic Gemini Board Context)
  - `main.py` (API Endpoints, Twilio Logic, Adaptive Scoring)
  - `requirements.txt` (FastAPI, Google SDKs, Twilio, etc.)
- `frontend/voiceguru_app/`
  - `lib/providers/` (Language, Streak state)
  - `lib/screens/` (Onboarding, Chat, History, Progress, Profile, Quiz)
  - `lib/services/` (API, TTS, Voice/STT, Local SQLite Library)
  - `lib/widgets/` (Streak Banner, Diagram, Mascot, XP Toast)

## Flutter App Refinements
- **UI/UX Excellence**: Custom `SlideTransition`, `.slideY` bubble animations, optimized suggestion cards.
- **Gamification**: Animated Duolingo-style fire banners, interactive 30-day calendars, subject progress bars, and achievement badges (Stars, Speed Learner, etc.).
- **Fixes**: Resolved layout bracket issues, updated to `kBackground`, and robust error handling for missing APIs.

## Backend Deployment (Render)
- **Status**: Live at `https://voiceguru-backend.onrender.com`.
- **Credentials Handling**: `.env` and `*.json` service accounts are explicitly `.gitignore`d. The backend intelligently parses raw JSON strings for `GOOGLE_APPLICATION_CREDENTIALS` so users can paste JSON directly into Render environment variables.
- **CI/CD**: Automatic deployment from GitHub `main` branch.
