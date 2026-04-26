# VoiceGuru 🦉

A hyper-personalized, voice-first AI tutoring platform built specifically for State Board and CBSE students. VoiceGuru transforms the educational experience by delivering dynamic, curriculum-accurate, and highly engaging tutoring natively in the student's preferred language.

Download the App and install directly👇🏻
https://drive.google.com/drive/folders/1qzCmSYsBsvorU_Q25txpOWG18jPm9yEa
---

## 🌟 Key Features

### 🎙️ Multilingual & Voice-First Interaction
Children interact with VoiceGuru exactly like a real teacher. The app uses on-device Speech-to-Text to listen to their questions and responds with warm, human-like Text-to-Speech (TTS) explanations in **Kannada, Hindi, Tamil, and English**.

### 🧠 Adaptive Difficulty Engine
VoiceGuru is uniquely capable of analyzing a student's performance to scale the complexity of its answers dynamically. 
- Automatically evaluates quiz scores to classify the child as a `Beginner`, `Intermediate`, or `Advanced` learner.
- Adjusts teaching strategies on the fly (e.g., breaking concepts into smaller steps for beginners or introducing advanced real-world applications for advanced learners).

### 📚 Dynamic Syllabus Context
Instead of providing generic internet answers, the app strictly adheres to the student's curriculum (like NCERT or the Karnataka State Board). It dynamically generates syllabus boundaries for any given grade and subject to ensure answers remain perfectly relevant for school exams.

### 📴 Smart Offline Library
To support students in areas with unstable internet connections, VoiceGuru features "Silent Caching."
- Every successful AI explanation is silently cached in a local SQLite database.
- When offline, students can still query previously learned concepts and receive instant, cached AI answers via fuzzy keyword matching.

### 🎮 Gamified Learning & Progress Analytics
We make learning addictive (in a good way!):
- **Interactive Dashboards**: Beautiful custom-painted weekly and monthly progress charts.
- **Achievements**: Unlockable badges like *Speed Learner*, *Science Explorer*, and *Math Wizard*.
- **Streaks**: Duolingo-style fire streaks and daily question goals that trigger local confetti animations upon completion.

### 📱 Automated Parent Reporting (Twilio)
Parents stay effortlessly involved. The backend automatically compiles weekly AI-generated performance summaries (including subject breakdowns and streak info) and sends them directly to parents via **WhatsApp** using the Twilio SDK.

### 📸 Vision Solver
Stuck on a diagram? The app features an image-upload pipeline (`/ask_image`) that acts as a homework guide, providing step-by-step guidance without just giving away the final answer immediately.

---

## 🛠️ Tech Stack

**Frontend (Mobile App)**
- **Framework**: Flutter (Material 3)
- **State Management**: Provider (`ChangeNotifier`)
- **Local Storage**: `shared_preferences`, `sqflite` (Smart Offline Library)
- **Animations**: `flutter_animate`, Custom Painters
- **Device Features**: `speech_to_text`, `flutter_tts`, `connectivity_plus`

**Backend (API & AI)**
- **Framework**: Python / FastAPI
- **AI Models**: Google Gemini 2.5 Flash (`google-genai` V2 SDK)
- **Database**: Firebase / Firestore (Multi-child data deduplication & analytics)
- **Integrations**: Twilio (WhatsApp API)

---

## 🚀 Setup and Installation

### 1. Backend Setup

Navigate to the backend directory:
```bash
cd backend
```

Create a virtual environment and install the required dependencies:
```bash
python -m venv .venv
source .venv/bin/activate  # On Windows use: .venv\Scripts\activate
pip install -r requirements.txt
```

**Environment Variables**
Create a `.env` file in the `backend/` directory:
```env
GEMINI_API_KEY=your_gemini_api_key_here
YOUTUBE_API_KEY=your_youtube_api_key_here
TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_WHATSAPP_NUMBER=whatsapp:+14155238886
```

**Run the Server**
```bash
python main.py
# Server runs on http://127.0.0.1:8000
```

### 2. Frontend Setup

Navigate to the frontend directory:
```bash
cd frontend/voiceguru_app
```

Install Flutter dependencies:
```bash
flutter pub get
```

*Note: If running on an Android Emulator and targeting the local backend, be sure to reverse the TCP port so the emulator can access localhost:*
```bash
adb reverse tcp:8000 tcp:8000
```

**Run the App**
```bash
flutter run
```

---

## 💡 How to Demo the Offline Feature
1. While connected to the internet, ask a question like *"What is photosynthesis?"* or *"Why is the sky blue?"*
2. Wait for VoiceGuru to fully answer the question.
3. Turn off your device's Wi-Fi and Cellular Data (Airplane Mode).
4. Ask the exact same question or a similar variation.
5. Watch as VoiceGuru instantly retrieves the cached explanation from the local SQLite database without needing an internet connection!

---

*Designed and developed to make quality education accessible and engaging for every child.*
