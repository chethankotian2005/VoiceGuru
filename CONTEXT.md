# VoiceGuru Build Context

Last Updated: 2026-04-26T08:12:00+05:30

## Project Overview
VoiceGuru is a voice-first AI tutoring app for Karnataka State Board students, designed to provide a personalized, multi-child learning experience.
- **Backend**: FastAPI (Python) hosting AI agents, progress analytics, and deployment on Render.
- **AI Agents**: Gemini-based (google-genai V2) Classifier, Explainer (with Homework Solver), and Simplifier agents.
- **Database**: Firestore with a multi-child architecture (segmented by `child_id`).
- **Frontend**: Flutter (Material 3) with a highly animated, gamified UI and localized support.

## Current Folder Structure
- `backend/`
  - `agents/` (Classifier, Explainer/Solver, Simplifier, Quiz)
  - `firebase_logger.py` (Multi-child Firestore logic, Analytics, & Deduplication)
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

## Backend API & Logic (Current)

### 👤 User Management & Deduplication
- **POST /create_user**: Persists child profile metadata. Now includes **Deduplication Logic**.
- **find_existing_user**: Backend helper that searches for Name + Grade matches in Firestore to prevent duplicate IDs.
- **Sync Workflow**: If a match is found, the backend returns the existing `child_id`, which the frontend then adopts locally to recover history/progress.

### 📚 AI Tutoring & Homework
- **POST /ask**: Standard text-based tutor response.
- **POST /ask_image**: Step-by-Step Homework Solver with guided steps and hints.
- **POST /simplify**: Simplifies complex explanations for younger students.

### 📊 Progress & Dashboard
- **GET /progress/{child_id}**: Aggregates streaks, badges, and subject breakdown.
- **GET /dashboard/{child_id}/report**: Gemini-generated HTML weekly reports for parents.

### 🎙️ Audio & Vision
- **POST /transcribe**: STT with multilingual hotword detection ("Hey VoiceGuru").
- **GET /speak**: Google Cloud TTS (Wavenet) synthesis.
- **GET /suggestions**: Grade/Language aware topic suggestions (UI compatibility fixed with `.withOpacity`).

## Flutter App Refinements

### 🎨 UI/UX Excellence
- **Page Transitions**: Custom `SlideTransition` for all primary navigation.
- **Message Animations**: Bubbles use `.slideY` + `.fadeIn` for a premium feel.
- **Suggestion Cards**: Optimized aspect ratio (0.85) and compatibility fixes for older Flutter versions.
- **Mascot Interactions**: Interactive reactions integrated into the chat flow.

### 🎮 Gamification & Navigation
- **Streak System**: Animated Duolingo-style fire banners.
- **Quiz Navigation Fix**: Results screen now uses a callback (`onBackToLearning`) to switch tabs instead of popping, preventing "black screen" errors.
- **Onboarding**: Form validation and automatic server-side profile syncing.

## Backend Deployment (Render)
- **Status**: Live at `https://voiceguru-backend.onrender.com`.
- **Security**: Environment variables used for `GOOGLE_APPLICATION_CREDENTIALS` (supports raw JSON).
- **CI/CD**: Automatic deployment from GitHub `main` branch.

## Notes for AI/User
- **Data Isolation**: All learner data is segmented by `child_id`.
- **Cross-Language Stability**: Navigation and state management tested across English, Kannada, Hindi, and Tamil.
- **Legacy Support**: UI widgets use `.withOpacity` instead of `.withValues` for maximum device compatibility.
