# VoiceGuru Flutter App

VoiceGuru is a voice-first tutoring app frontend for Karnataka State Board students.

## Features
- Home screen with mic-first ask flow
- Language and grade selection
- Explanation rendering with replay/simplify actions
- History screen backed by the backend `/history/{child_id}` API

## Run Locally
1. Ensure backend is running on port `8000`.
2. From this directory run:
	- `flutter pub get`
	- `flutter run -d chrome`

## Backend Expectations
- `POST /ask`
- `POST /simplify`
- `GET /history/{child_id}`
- `GET /speak`
- `GET /status`
