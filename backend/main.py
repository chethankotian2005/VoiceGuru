from __future__ import annotations

import base64
import asyncio
import os
import re
from typing import Literal, Optional
import json
from collections import defaultdict
from datetime import datetime, timedelta
from cachetools import TTLCache
from google import genai
import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from firebase_logger import get_child_history, log_question, get_progress_data, get_today_topics, save_quiz_result, save_user_profile, find_existing_user
from pipeline import run_simplify_pipeline, run_voiceguru_pipeline
from agents.quiz_agent import generate_quiz as run_quiz_agent

try:
    from google.cloud import texttospeech
except Exception:  # pragma: no cover - handled safely at runtime
    texttospeech = None

try:
    from google.cloud import speech
except Exception:  # pragma: no cover - handled safely at runtime
    speech = None

load_dotenv()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
YOUTUBE_API_KEY = os.getenv("YOUTUBE_API_KEY", "")


suggestions_cache = TTLCache(maxsize=100, ttl=3600)

# Store last 10 messages per child for context
conversation_history = defaultdict(list)

def get_conversation_context(child_id: str) -> str:
    history = conversation_history[child_id]
    if not history:
        return ""
    
    # Build context string from last 5 exchanges
    context_parts = []
    for exchange in history[-5:]:
        context_parts.append(
            f"Child asked: {exchange['question']}"
        )
        context_parts.append(
            f"VoiceGuru answered: {exchange['answer'][:100]}..."
        )
    return "\n".join(context_parts)

def add_to_history(child_id: str, question: str, answer: str):
    conversation_history[child_id].append({
        "question": question,
        "answer": answer,
        "timestamp": datetime.now()
    })
    # Keep only last 10 exchanges
    if len(conversation_history[child_id]) > 10:
        conversation_history[child_id].pop(0)

def clear_old_sessions():
    """Clear sessions older than 2 hours to save memory."""
    cutoff = datetime.now() - timedelta(hours=2)
    for child_id in list(conversation_history.keys()):
        conversation_history[child_id] = [
            h for h in conversation_history[child_id]
            if h['timestamp'] > cutoff
        ]
        if not conversation_history[child_id]:
            del conversation_history[child_id]

app = FastAPI(title="VoiceGuru Backend", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"message": "VoiceGuru Backend is LIVE!", "ip": "10.36.0.144"}


class AskRequest(BaseModel):
    text: str = Field(default="", description="Child question as text")
    language: Literal["kannada", "hindi", "tamil", "english"] = "english"
    grade: int = Field(default=6, ge=1, le=10)
    child_id: str
    board: str = "Karnataka State Board"


class AskImageRequest(BaseModel):
    image_base64: str = Field(..., description="Base64 encoded image (jpeg/png)")
    language: Literal["kannada", "hindi", "tamil", "english"] = "english"
    grade: int = Field(default=6, ge=1, le=10)
    child_id: str
    additional_context: Optional[str] = None


class AskResponse(BaseModel):
    explanation: str
    subject: str
    grade_used: int
    language: str
    agent_trace: list[str]
    needs_diagram: bool = False
    diagram_description: Optional[str] = None
    diagram_type: str = "none"
    youtube_search_query: Optional[str] = None
    key_terms: list[str] = []
    # Step-by-step homework solving fields
    steps: list[str] = []
    final_answer: Optional[str] = None
    hint: Optional[str] = None


class SimplifyRequest(BaseModel):
    original_question: str
    original_explanation: str
    language: str
    grade: int = Field(default=6, ge=1, le=10)
    child_id: str


class SimplifyResponse(BaseModel):
    simplified_explanation: str


class SpeakResponse(BaseModel):
    audio_base64: str
    language: str


class TranscribeRequest(BaseModel):
    audio_base64: str = Field(..., description="Base64 encoded audio data")
    language: Literal["kannada", "hindi", "tamil", "english"] = "english"


class TranscribeResponse(BaseModel):
    text: str
    is_hotword: bool = False


class QuizGenerateRequest(BaseModel):
    child_id: str
    grade: int = Field(default=7, ge=1, le=10)
    language: Literal["kannada", "hindi", "tamil", "english"] = "english"
    num_questions: int = Field(default=5, ge=1, le=10)


class QuizAnswer(BaseModel):
    question_index: int
    selected: str


class QuizSubmitRequest(BaseModel):
    child_id: str
    answers: list[QuizAnswer]
    grade: int = Field(default=7, ge=1, le=10)
    language: Literal["kannada", "hindi", "tamil", "english"] = "english"
    hotword_detected: Optional[str] = None


class YouTubeVideoResult(BaseModel):
    title: str
    video_id: str
    thumbnail: str
    channel: str


class YouTubeSearchResponse(BaseModel):
    results: list[YouTubeVideoResult] = []


class SuggestionItem(BaseModel):
    text: str
    query: str
    emoji: str
    category: str
    subject: str

class SuggestionsResponse(BaseModel):
    suggestions: list[SuggestionItem] = []

class CreateUserRequest(BaseModel):
    child_id: str
    name: str
    grade: int = Field(default=6, ge=1, le=10)
    board: str = "Karnataka State Board"
    language: str = "english"
    mascot: str = "owl"

class WeeklyData(BaseModel):
    day: str
    questions: int
    date: str

class MonthlyData(BaseModel):
    week: str
    questions: int

class ProgressResponse(BaseModel):
    streak_days: int
    total_questions: int
    today_questions: int
    daily_goal: int
    weekly_data: list[WeeklyData] = []
    monthly_data: list[MonthlyData] = []
    subject_breakdown: dict[str, int] = {}
    badges: list[str] = []

# --------------- Hotword detection ---------------

HOTWORD_VARIATIONS: list[str] = [
    "hey voiceguru",
    "hey voice guru",
    "ಹೇ ವಾಯ್ಸ್ಗುರು",
    "हे वॉयस गुरु",
]


def _detect_hotword(text: str) -> tuple[bool, Optional[str]]:
    """Return (is_hotword, matched_hotword) from the transcribed text."""
    normalised = text.strip().lower()
    for hw in HOTWORD_VARIATIONS:
        if hw.lower() in normalised:
            return True, hw
    return False, None


# --------------- YouTube helpers ---------------

YOUTUBE_SEARCH_URL = "https://www.googleapis.com/youtube/v3/search"

# Channels to BLOCK (non-educational content)
NON_EDUCATIONAL_CHANNEL_KEYWORDS: list[str] = [
    "music", "song", "vlog", "gaming", "gamer", "funny",
    "meme", "prank", "news", "entertainment", "comedy",
    "trailer", "movie", "film", "cricket", "sport",
]


def _fire_and_forget_log(coro) -> None:
    try:
        task = asyncio.create_task(coro)

        def _swallow_exception(completed_task: asyncio.Task) -> None:
            try:
                completed_task.result()
            except Exception:
                pass

        task.add_done_callback(_swallow_exception)
    except Exception:
        pass


def _tts_language_code(language: str) -> str:
    mapping = {
        "kannada": "kn-IN",
        "hindi": "hi-IN",
        "tamil": "ta-IN",
        "english": "en-IN",
    }
    return mapping.get((language or "").strip().lower(), "en-IN")


    return mapping.get((language or "").strip().lower(), "en-IN-Wavenet-A")


def convert_to_ssml(text: str) -> str:
    """Convert plain text to SSML with natural pauses and emphasis for child-friendly speech."""
    # Wrap in SSML speak tags
    ssml = '<speak>'
    
    # Add a warm greeting pause at start
    ssml += '<prosody rate="90%" pitch="+1.5st">'
    
    # Split into sentences and add natural pauses
    sentences = re.split(r'(?<=[.!?])\s+', text.strip())
    
    for i, sentence in enumerate(sentences):
        if not sentence:
            continue
            
        # Add emphasis to key educational terms (capitalized words)
        sentence = re.sub(
            r'\b([A-Z][a-z]+(?:\s[A-Z][a-z]+)*)\b',
            r'<emphasis level="moderate">\1</emphasis>',
            sentence
        )
        
        ssml += sentence
        if i < len(sentences) - 1:
            ssml += '<break time="400ms"/>'
    
    ssml += '</prosody>'
    ssml += '</speak>'
    
    return ssml


@app.post("/create_user")
async def create_user(payload: CreateUserRequest):
    try:
        # Check for duplicates based on Name and Grade
        existing_id = await find_existing_user(payload.name, payload.grade)
        
        # If user exists, we use their existing ID to avoid duplicates
        # If not, we use the one provided by the frontend
        final_id = existing_id if existing_id else payload.child_id
        
        await save_user_profile(
            child_id=final_id,
            name=payload.name,
            grade=payload.grade,
            board=payload.board,
            language=payload.language,
            mascot=payload.mascot,
        )
        return {"status": "success", "child_id": final_id}
    except Exception as e:
        return {"status": "error", "message": str(e)}


@app.post("/clear_context")
async def clear_context(child_id: str = Query(...)):
    """Clears the in-memory conversation context for a specific child."""
    if child_id in conversation_history:
        del conversation_history[child_id]
    return {"status": "success", "message": f"Context cleared for {child_id}"}


@app.post("/ask", response_model=AskResponse)
async def ask(payload: AskRequest) -> AskResponse:
    try:
        # Get conversation context for memory
        conversation_ctx = get_conversation_context(payload.child_id)
        
        pipeline_result = await run_voiceguru_pipeline(
            question=payload.text,
            language=payload.language,
            grade=payload.grade,
            child_id=payload.child_id,
            conversation_context=conversation_ctx,
            board=payload.board,
        )
        
        # Add current exchange to history
        add_to_history(
            payload.child_id, 
            payload.text, 
            str(pipeline_result.get("explanation", ""))
        )
        
        # Periodically clear old sessions (every 100 requests roughly)
        if os.getpid() % 100 == 0:
            clear_old_sessions()
            
        response = AskResponse(
            explanation=str(pipeline_result.get("explanation", "")),
            subject=str(pipeline_result.get("subject", "General")),
            grade_used=int(pipeline_result.get("grade_used", payload.grade)),
            language=str(pipeline_result.get("language", payload.language)),
            # Keep trace contract stable for frontend and docs.
            agent_trace=["Classifier", "Explainer"],
            needs_diagram=bool(pipeline_result.get("needs_diagram", False)),
            diagram_description=pipeline_result.get("diagram_description"),
            diagram_type=str(pipeline_result.get("diagram_type", "none")),
            youtube_search_query=pipeline_result.get("youtube_search_query"),
            key_terms=pipeline_result.get("key_terms", []),
        )

        _fire_and_forget_log(
            log_question(
                child_id=payload.child_id,
                question=payload.text,
                explanation=response.explanation,
                subject=response.subject,
                grade=response.grade_used,
                language=response.language,
            )
        )
        return response
    except Exception:
        response = AskResponse(
            explanation="I could not process that fully, but I am still here to help. Please try again.",
            subject="General",
            grade_used=payload.grade,
            language=payload.language,
            agent_trace=["Classifier", "Explainer"],
        )
        _fire_and_forget_log(
            log_question(
                child_id=payload.child_id,
                question=payload.text,
                explanation=response.explanation,
                subject=response.subject,
                grade=payload.grade,
                language=payload.language,
            )
        )
        return response


@app.post("/ask_image", response_model=AskResponse)
async def ask_image(payload: AskImageRequest) -> AskResponse:
    if not GEMINI_API_KEY:
        return AskResponse(
            explanation="Gemini API key is missing.",
            subject="General",
            grade_used=payload.grade,
            language=payload.language,
            agent_trace=["Explainer"],
        )
    
    try:
        client = genai.Client(api_key=GEMINI_API_KEY)
        
        # Clean base64 string if it contains data URI scheme
        b64_data = payload.image_base64
        if "," in b64_data:
            b64_data = b64_data.split(",")[1]
            
        image_bytes = base64.b64decode(b64_data)
        
        prompt = f"""You are VoiceGuru, a warm and encouraging tutor for Class {payload.grade} Karnataka State Board students.

Look at this image carefully. A student needs your help with what is shown.

IMPORTANT TEACHING RULES:
1. DO NOT just give the answer directly — guide the student like a real teacher would
2. Break the solution into clear numbered steps (3-5 steps)
3. Use simple LOCAL examples where helpful (auto, idli, cricket bat, rupees, etc.)
4. If it is MATH: show working step by step, not just the final answer
5. If it is a DIAGRAM: label each part and explain what it does
6. If it is TEXT/QUESTION: identify the concept first, then guide through reasoning
7. Respond ENTIRELY in {payload.language}
8. Keep it child-friendly for Class {payload.grade} — under 200 words total
{f'Extra context from student: {payload.additional_context}' if payload.additional_context else ''}

You MUST respond with ONLY a valid JSON object — no markdown, no code fences.
JSON SCHEMA (follow exactly):
{{
  "explanation": "A friendly 1-2 sentence overview of what you see and what you will help with",
  "steps": [
    "Step 1: [First guided step — ask a question or show first piece]",
    "Step 2: [Build on step 1 — show working or next concept]",
    "Step 3: [Continue — connect to something the student knows]",
    "Step 4: [Optional — final reasoning step before reveal]"
  ],
  "final_answer": "The complete answer or solution, revealed only after steps",
  "subject": "math or science or social_studies or other",
  "hint": "A gentle hint if the student gets stuck (1 sentence)",
  "needs_diagram": true or false,
  "diagram_description": "describe what diagram would help, or null",
  "diagram_type": "one of: ray_diagram | food_chain | water_cycle | number_line | geometric_shape | human_body | solar_system | circuit | bar_chart | none",
  "youtube_search_query": "specific educational search query for YouTube, or null",
  "key_terms": ["term1", "term2"]
}}"""

        response = await asyncio.to_thread(
            client.models.generate_content,
            model='gemini-2.5-flash',
            contents=[
                genai.types.Part.from_bytes(data=image_bytes, mime_type='image/jpeg'),
                prompt
            ],
            config=genai.types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.4,
            )
        )
        
        raw_text = getattr(response, "text", "")
        # Clean markdown fences if any
        if raw_text.startswith("```"):
            first_newline = raw_text.find("\\n")
            if first_newline != -1:
                raw_text = raw_text[first_newline + 1:]
            if raw_text.endswith("```"):
                raw_text = raw_text[:-3].strip()

        try:
            parsed = json.loads(raw_text)
        except json.JSONDecodeError:
            parsed = {"explanation": raw_text}

        raw_steps = parsed.get("steps", [])
        steps_list = raw_steps if isinstance(raw_steps, list) else []

        ask_response = AskResponse(
            explanation=str(parsed.get("explanation", "I could not analyze the image properly.")),
            subject=str(parsed.get("subject", "General")),
            grade_used=payload.grade,
            language=payload.language,
            agent_trace=["VisionExplainer"],
            needs_diagram=bool(parsed.get("needs_diagram", False)),
            diagram_description=parsed.get("diagram_description"),
            diagram_type=str(parsed.get("diagram_type", "none")),
            youtube_search_query=parsed.get("youtube_search_query"),
            key_terms=parsed.get("key_terms", []) if isinstance(parsed.get("key_terms"), list) else [],
            steps=[str(s) for s in steps_list],
            final_answer=parsed.get("final_answer"),
            hint=parsed.get("hint"),
        )
        
        _fire_and_forget_log(
            log_question(
                child_id=payload.child_id,
                question="[Image Uploaded]",
                explanation=ask_response.explanation,
                subject=ask_response.subject,
                grade=ask_response.grade_used,
                language=ask_response.language,
            )
        )
        
        return ask_response
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        err_response = AskResponse(
            explanation="I had some trouble looking at that image. Can you try again?",
            subject="General",
            grade_used=payload.grade,
            language=payload.language,
            agent_trace=["VisionExplainer"],
        )
        return err_response


@app.post("/simplify", response_model=SimplifyResponse)
async def simplify(payload: SimplifyRequest) -> SimplifyResponse:
    try:
        pipeline_result = await run_simplify_pipeline(
            original_question=payload.original_question,
            original_explanation=payload.original_explanation,
            language=payload.language,
            grade=payload.grade,
        )
        simplified = pipeline_result.get("simplified_explanation", "I can simplify this once you share more details.")
        _fire_and_forget_log(
            log_question(
                child_id=payload.child_id,
                question=payload.original_question,
                explanation=simplified,
                subject="Simplification",
                grade=payload.grade,
                language=payload.language,
            )
        )
        return SimplifyResponse(simplified_explanation=simplified)
    except Exception:
        simplified = "I could not simplify this right now, but please try again in a moment."
        _fire_and_forget_log(
            log_question(
                child_id=payload.child_id,
                question=payload.original_question,
                explanation=simplified,
                subject="Simplification",
                grade=payload.grade,
                language=payload.language,
            )
        )
        return SimplifyResponse(simplified_explanation=simplified)


# ─── Quiz state: in-memory cache keyed by child_id ───
_quiz_cache: dict[str, list[dict]] = {}


@app.post("/generate_quiz")
async def generate_quiz(payload: QuizGenerateRequest):
    try:
        topics = await get_today_topics(payload.child_id)
        if not topics:
            # Fallback: grade-appropriate generic topics
            grade_topics = {
                1: ["numbers", "shapes", "animals", "plants", "my family"],
                2: ["addition", "subtraction", "water", "food", "festivals"],
                3: ["multiplication", "time", "weather", "our body", "community helpers"],
                4: ["fractions", "measurement", "solar system", "states of matter", "maps"],
                5: ["decimals", "geometry", "human body systems", "natural resources", "indian history"],
                6: ["ratio proportion", "algebra basics", "cells", "magnetism", "ancient civilizations"],
                7: ["integers", "triangles", "photosynthesis", "acids bases", "mughal empire"],
                8: ["linear equations", "quadrilaterals", "reproduction in plants", "sound", "indian constitution"],
                9: ["polynomials", "coordinate geometry", "atoms molecules", "gravity", "french revolution"],
                10: ["trigonometry", "statistics", "periodic table", "electricity", "nationalism in india"],
            }
            topics = grade_topics.get(payload.grade, ["general knowledge", "science", "math"])

        questions = await run_quiz_agent(
            grade=payload.grade,
            language=payload.language,
            topics=topics,
            num_questions=payload.num_questions,
        )

        # Cache the generated questions for submit validation
        _quiz_cache[payload.child_id] = questions

        return {
            "questions": questions,
            "topics": topics,
            "num_questions": len(questions),
        }
    except Exception:
        import traceback
        traceback.print_exc()
        return {"questions": [], "topics": [], "num_questions": 0}


@app.post("/submit_quiz")
async def submit_quiz(payload: QuizSubmitRequest):
    try:
        cached_questions = _quiz_cache.get(payload.child_id, [])
        if not cached_questions:
            return {"error": "No active quiz found. Please generate a quiz first."}

        total = len(cached_questions)
        score = 0
        results = []

        for answer in payload.answers:
            idx = answer.question_index
            if idx < 0 or idx >= total:
                results.append({
                    "correct": False,
                    "selected": answer.selected,
                    "correct_answer": "?",
                    "explanation": "Invalid question index",
                })
                continue

            q = cached_questions[idx]
            correct_answer = q.get("correct", "")
            is_correct = answer.selected.upper() == correct_answer.upper()
            if is_correct:
                score += 1

            results.append({
                "correct": is_correct,
                "selected": answer.selected,
                "correct_answer": correct_answer,
                "explanation": q.get("explanation", ""),
            })

        percentage = round((score / total) * 100) if total > 0 else 0

        # Stars logic
        if percentage >= 80:
            stars_earned = 3
        elif percentage >= 40:
            stars_earned = 2
        else:
            stars_earned = 1

        # Badge logic
        badge_earned = None
        if percentage == 100:
            badge_earned = "quiz_master"
        elif percentage >= 80:
            badge_earned = "quiz_star"

        # Persist to Firestore
        _fire_and_forget_log(
            save_quiz_result(
                child_id=payload.child_id,
                score=score,
                total=total,
                grade=payload.grade,
                language=payload.language,
            )
        )

        # Clear cache after submission
        _quiz_cache.pop(payload.child_id, None)

        return {
            "score": score,
            "total": total,
            "percentage": percentage,
            "results": results,
            "badge_earned": badge_earned,
            "stars_earned": stars_earned,
        }
    except Exception:
        import traceback
        traceback.print_exc()
        return {"score": 0, "total": 0, "percentage": 0, "results": [], "badge_earned": None, "stars_earned": 0}


@app.get("/speak", response_model=SpeakResponse)
async def speak(text: str, language: str) -> SpeakResponse:
    try:
        if not text.strip() or texttospeech is None:
            return SpeakResponse(audio_base64="", language=language)

        client = texttospeech.TextToSpeechClient()
        
        voice_config = {
            'kannada': {
                'language_code': 'kn-IN',
                'name': 'kn-IN-Wavenet-A',
                'gender': texttospeech.SsmlVoiceGender.FEMALE
            },
            'hindi': {
                'language_code': 'hi-IN', 
                'name': 'hi-IN-Wavenet-A',
                'gender': texttospeech.SsmlVoiceGender.FEMALE
            },
            'tamil': {
                'language_code': 'ta-IN',
                'name': 'ta-IN-Wavenet-A', 
                'gender': texttospeech.SsmlVoiceGender.FEMALE
            },
            'english': {
                'language_code': 'en-IN',
                'name': 'en-IN-Wavenet-D',
                'gender': texttospeech.SsmlVoiceGender.FEMALE
            }
        }
        
        config = voice_config.get(language, voice_config['english'])
        
        # Use SSML for emotional, natural speech
        ssml_text = convert_to_ssml(text)
        
        synthesis_input = texttospeech.SynthesisInput(ssml=ssml_text)
        
        voice = texttospeech.VoiceSelectionParams(
            language_code=config['language_code'],
            name=config['name'],
            ssml_gender=config['gender']
        )
        
        audio_config = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.MP3,
            speaking_rate=0.90,  # Slightly slower = clearer
            pitch=1.5,           # Slightly higher = friendlier
            volume_gain_db=1.0,
            effects_profile_id=['headphone-class-device']
        )

        response = await asyncio.to_thread(
            client.synthesize_speech,
            input=synthesis_input,
            voice=voice,
            audio_config=audio_config,
        )

        audio_content = getattr(response, "audio_content", b"") or b""
        return SpeakResponse(
            audio_base64=base64.b64encode(audio_content).decode("utf-8") if audio_content else "",
            language=language,
        )
    except Exception:
        return SpeakResponse(audio_base64="", language=language)


@app.get("/history/{child_id}")
async def history(child_id: str) -> list:
    try:
        return await get_child_history(child_id)
    except Exception:
        return []


@app.post("/transcribe", response_model=TranscribeResponse)
async def transcribe(payload: TranscribeRequest) -> TranscribeResponse:
    """Decode base64 audio ➜ Speech-to-Text ➜ hotword check."""
    try:
        if speech is None:
            return TranscribeResponse(text="", is_hotword=False, hotword_detected=None)

        audio_bytes = base64.b64decode(payload.audio_base64)
        if not audio_bytes:
            return TranscribeResponse(text="", is_hotword=False, hotword_detected=None)

        client = speech.SpeechClient()
        audio = speech.RecognitionAudio(content=audio_bytes)
        config = speech.RecognitionConfig(
            encoding=speech.RecognitionConfig.AudioEncoding.WEBM_OPUS,
            sample_rate_hertz=48000,
            language_code=_tts_language_code(payload.language),
            enable_automatic_punctuation=True,
        )

        response = await asyncio.to_thread(client.recognize, config=config, audio=audio)

        transcript_parts: list[str] = []
        for result in response.results:
            alt = result.alternatives[0] if result.alternatives else None
            if alt:
                transcript_parts.append(alt.transcript)

        full_text = " ".join(transcript_parts).strip()
        is_hotword, hotword_matched = _detect_hotword(full_text)

        return TranscribeResponse(
            text=full_text,
            is_hotword=is_hotword,
            hotword_detected=hotword_matched,
        )
    except Exception:
        return TranscribeResponse(text="", is_hotword=False, hotword_detected=None)


@app.get("/youtube_search", response_model=YouTubeSearchResponse)
async def youtube_search(
    query: str = Query(..., description="Search query for YouTube"),
    grade: int = Query(default=6, description="Student grade level"),
    max_results: int = Query(default=3, ge=1, le=10, description="Max results to return"),
) -> YouTubeSearchResponse:
    """Search YouTube Data API v3 for educational videos, filtered to trusted channels."""
    if not YOUTUBE_API_KEY:
        return YouTubeSearchResponse(results=[])

    try:
        params = {
            "part": "snippet",
            "q": query,
            "type": "video",
            "maxResults": max_results * 3,  # fetch extra to filter
            "order": "relevance",
            "safeSearch": "strict",
            "videoCategoryId": "27",  # Education category
            "key": YOUTUBE_API_KEY,
        }

        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(YOUTUBE_SEARCH_URL, params=params)
            resp.raise_for_status()
            data = resp.json()

        items = data.get("items", [])
        
        if 1 <= grade <= 5:
            preferred_channels = ["appu series", "pebbles kids", "smile and learn"]
        elif 6 <= grade <= 8:
            preferred_channels = ["byju's", "vedantu", "manocha academy"]
        else:
            preferred_channels = ["physics wallah", "vedantu", "unacademy", "khan academy india"]

        scored_results = []

        for item in items:
            snippet = item.get("snippet", {})
            channel_name = snippet.get("channelTitle", "")
            channel_lower = channel_name.lower()
            title = snippet.get("title", "")
            title_lower = title.lower()

            # Skip channels that are clearly non-educational
            is_blocked = any(
                kw in channel_lower for kw in NON_EDUCATIONAL_CHANNEL_KEYWORDS
            )
            if is_blocked:
                continue

            video_id = item.get("id", {}).get("videoId", "")
            if not video_id:
                continue

            thumbnails = snippet.get("thumbnails", {})
            thumb_url = (
                thumbnails.get("medium", {}).get("url")
                or thumbnails.get("default", {}).get("url", "")
            )
            
            score = 0
            if f"class {grade}" in title_lower or f"grade {grade}" in title_lower:
                score += 2
            
            if any(pc in channel_lower for pc in preferred_channels):
                score += 3
                
            if grade >= 7 and ("kids" in title_lower or "nursery" in title_lower):
                score -= 5

            scored_results.append({
                "score": score,
                "result": YouTubeVideoResult(
                    title=title,
                    video_id=video_id,
                    thumbnail=thumb_url,
                    channel=channel_name,
                )
            })

        scored_results.sort(key=lambda x: x["score"], reverse=True)
        filtered = [x["result"] for x in scored_results[:max_results]]

        return YouTubeSearchResponse(results=filtered)
    except Exception:
        return YouTubeSearchResponse(results=[])


@app.get("/suggestions", response_model=SuggestionsResponse)
async def get_suggestions(grade: int, language: str, subject: Optional[str] = None):
    language = str(language).lower().strip()
    cache_key = f"{grade}_{language}_{subject}"
    
    if cache_key in suggestions_cache:
        return SuggestionsResponse(suggestions=suggestions_cache[cache_key])
        
    fallback = [
        SuggestionItem(
            text="What is Photosynthesis?" if language == "english" else "ದ್ಯುತಿಸಂಶ್ಲೇಷಣೆ ಎಂದರೇನು?",
            query="Explain photosynthesis" if language == "english" else "ದ್ಯುತಿಸಂಶ್ಲೇಷಣೆಯನ್ನು ವಿವರಿಸಿ",
            emoji="🌿",
            category="curriculum",
            subject="science"
        ),
        SuggestionItem(
            text="Tell me a space fact!" if language == "english" else "ಬಾಹ್ಯಾಕಾಶದ ಬಗ್ಗೆ ಒಂದು ವಾಸ್ತವ ಹೇಳಿ!",
            query="Tell me an interesting fact about space" if language == "english" else "ಬಾಹ್ಯಾಕಾಶದ ಬಗ್ಗೆ ಒಂದು ಆಸಕ್ತಿದಾಯಕ ವಾಸ್ತವವನ್ನು ಹೇಳಿ",
            emoji="🚀",
            category="curiosity",
            subject="science"
        ),
        SuggestionItem(
            text="Ask me a riddle" if language == "english" else "ನನ್ನನ್ನೊಂದು ಒಗಟು ಕೇಳಿ",
            query="Tell me a riddle" if language == "english" else "ಒಂದು ಒಗಟು ಹೇಳಿ",
            emoji="🤔",
            category="fun",
            subject="fun"
        ),
    ]

    if not GEMINI_API_KEY:
        return SuggestionsResponse(suggestions=fallback)

    try:
        client = genai.Client(api_key=GEMINI_API_KEY)
        
        prompt = f"""Generate 6 topic suggestions for a Grade {grade} student exploring educational content.
The language of the response and suggestions MUST be {language}. If {language} is not English, translate everything to {language} accurately.
{f'Focus slightly on the subject: {subject}.' if subject else ''}

Output strictly valid JSON with this exact schema:
[
  {{
    "text": "short display text max 5 words",
    "query": "the full question/prompt behind the suggestion",
    "emoji": "a relevant single emoji",
    "category": "curriculum" | "curiosity" | "fun",
    "subject": "math" | "science" | "social_studies" | "fun"
  }}
]

Requirements:
- Ensure 3 suggestions are "curriculum" (Karnataka State Board curriculum based for Grade {grade}).
- Ensure 2 suggestions are "curiosity" (interesting science/world facts for Grade {grade}).
- Ensure 1 suggestion is "fun" (riddle, interesting fact, "did you know", creative)."""
        
        response = await asyncio.to_thread(
            client.models.generate_content,
            model='gemini-2.5-flash-lite',
            contents=prompt,
            config=genai.types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.7,
            )
        )
        
        data = json.loads(response.text)
        suggestions = []
        for item in data:
            suggestions.append(SuggestionItem(
                text=item.get("text", ""),
                query=item.get("query", ""),
                emoji=item.get("emoji", "💡"),
                category=item.get("category", "fun"),
                subject=item.get("subject", "fun")
            ))
            
        if len(suggestions) < 3:
            raise ValueError("Too few suggestions")
            
        suggestions_cache[cache_key] = suggestions
        return SuggestionsResponse(suggestions=suggestions)
        
    except Exception as e:
        print(f"Suggestions generation failed: {e}")
        return SuggestionsResponse(suggestions=fallback)

@app.get("/progress/{child_id}", response_model=ProgressResponse)
async def progress(child_id: str):
    data = await get_progress_data(child_id)
    return ProgressResponse(**data)


# ─────────────────────────────────────────────────────────────
#  PARENT / TEACHER DASHBOARD  (no auth required — child_id is
#  opaque enough for a hackathon / demo context)
# ─────────────────────────────────────────────────────────────

from fastapi.responses import HTMLResponse

async def _build_dashboard_data(child_id: str) -> dict:
    """Aggregate Firestore data into the dashboard JSON shape."""
    from firebase_logger import get_progress_data, get_child_history, get_user_profile

    prefs_key = f"profile:{child_id}"
    # Fetch user profile metadata
    user_profile = await get_user_profile(child_id)

    # Fetch structured progress (reuses existing logic)
    progress = await get_progress_data(child_id)

    # Fetch recent history for topic extraction and quiz scores
    history = await get_child_history(child_id)  # last 20 docs

    # Extract recent topics from question text (first 5 words each)
    recent_topics: list[str] = []
    seen: set[str] = set()
    for h in history:
        q = str(h.get("question", "")).strip()
        if q and q not in seen:
            seen.add(q)
            # Shorten to a meaningful phrase
            words = q.split()[:5]
            topic = " ".join(words).rstrip("?.,!").lower()
            if topic:
                recent_topics.append(topic)
        if len(recent_topics) >= 5:
            break

    subjects = progress.get("subject_breakdown", {})
    total = progress.get("total_questions", 0)
    this_week = sum(d["questions"] for d in progress.get("weekly_data", []))

    # Derive simple strengths / attention areas from subject ratios
    strengths: list[str] = []
    attention: list[str] = []
    subject_map = {
        "math": ("fractions & algebra", "math"),
        "science": ("science concepts", "science"),
        "social_studies": ("history & geography", "social studies"),
    }
    for key, (strength_label, attention_label) in subject_map.items():
        count = subjects.get(key, 0)
        if total > 0:
            ratio = count / total
            if ratio >= 0.35:
                strengths.append(strength_label)
            elif ratio < 0.1 and count < 3:
                attention.append(attention_label)

    # Pull quiz scores from history (quiz_results collection via firebase_logger)
    quiz_scores: list[dict] = []
    try:
        from firebase_logger import _get_firestore_client
        client = _get_firestore_client()
        if client:
            def _fetch_quiz():
                docs = (
                    client.collection("quiz_results")
                    .where("child_id", "==", child_id)
                    .order_by("timestamp", direction="DESCENDING")
                    .limit(5)
                    .stream()
                )
                results = []
                for doc in docs:
                    d = doc.to_dict() or {}
                    ts = d.get("timestamp")
                    date_str = ""
                    if ts and hasattr(ts, "date"):
                        date_str = ts.date().isoformat()
                    elif ts and hasattr(ts, "timestamp"):
                        from datetime import datetime, timezone
                        date_str = datetime.fromtimestamp(ts.timestamp(), tz=timezone.utc).date().isoformat()
                    results.append({
                        "date": date_str,
                        "score": int(d.get("score", 0)),
                        "total": int(d.get("total", 5)),
                    })
                return results
            import asyncio
            quiz_scores = await asyncio.to_thread(_fetch_quiz)
    except Exception:
        pass

    child_name = child_id.replace("_", " ").title()
    grade = history[0].get("grade", 6) if history else 6
    if user_profile:
        child_name = user_profile.get("name", child_name)
        grade = user_profile.get("grade", grade)

    return {
        "child_name": child_name,
        "grade": grade,
        "streak_days": progress.get("streak_days", 0),
        "total_questions": total,
        "this_week_questions": this_week,
        "subjects_breakdown": subjects,
        "recent_topics": recent_topics,
        "quiz_scores": quiz_scores,
        "areas_needing_attention": attention if attention else ["Keep exploring all subjects!"],
        "strengths": strengths if strengths else ["Curious learner"],
        "weekly_data": progress.get("weekly_data", []),
    }


@app.get("/dashboard/{child_id}")
async def dashboard_json(child_id: str):
    """JSON dashboard for programmatic access."""
    return await _build_dashboard_data(child_id)


@app.get("/dashboard/{child_id}/report")
async def dashboard_report(child_id: str):
    """Gemini-generated weekly narrative report for teachers/parents."""
    data = await _build_dashboard_data(child_id)
    if not GEMINI_API_KEY:
        return {"report": f"{data['child_name']} is making steady progress with VoiceGuru!"}

    try:
        client = genai.Client(api_key=GEMINI_API_KEY)
        prompt = f"""You are a friendly AI tutor assistant writing a brief weekly report for a parent or teacher.

Child: {data['child_name']}, Grade {data['grade']}
Streak: {data['streak_days']} days
Total questions this week: {data['this_week_questions']}
Subjects practiced: {data['subjects_breakdown']}
Recent topics explored: {', '.join(data['recent_topics']) or 'Various topics'}
Strengths: {', '.join(data['strengths'])}
Areas needing attention: {', '.join(data['areas_needing_attention'])}

Write a warm, encouraging 3-paragraph report in English (max 120 words total):
1. Summary of this week's learning
2. Strengths observed
3. Recommendations for next week

Use simple language a parent can understand. Be positive and specific."""

        response = await asyncio.to_thread(
            client.models.generate_content,
            model="gemini-2.5-flash-lite",
            contents=prompt,
            config=genai.types.GenerateContentConfig(temperature=0.6),
        )
        report_text = response.text.strip()
    except Exception as e:
        report_text = (
            f"{data['child_name']} has been actively learning this week! "
            f"They explored {data['this_week_questions']} questions covering multiple subjects. "
            f"Keep up the great work!"
        )

    return {"report": report_text, "data": data}


@app.get("/dashboard/{child_id}/html", response_class=HTMLResponse)
async def dashboard_html(child_id: str):
    """Mobile-friendly HTML dashboard for teachers/parents — no login required."""
    data = await _build_dashboard_data(child_id)
    try:
        client = genai.Client(api_key=GEMINI_API_KEY) if GEMINI_API_KEY else None
        if client:
            prompt = f"""Write a concise 2-3 sentence teacher recommendation for {data['child_name']} (Grade {data['grade']}).
Strengths: {', '.join(data['strengths'])}.  Areas to improve: {', '.join(data['areas_needing_attention'])}.
Recent topics: {', '.join(data['recent_topics'])}.
Be warm, specific, and end with one actionable tip."""
            rec_resp = await asyncio.to_thread(
                client.models.generate_content,
                model="gemini-2.5-flash-lite",
                contents=prompt,
                config=genai.types.GenerateContentConfig(temperature=0.5),
            )
            recommendation = rec_resp.text.strip()
        else:
            recommendation = f"{data['child_name']} is making good progress. Encourage them to keep their streak going!"
    except Exception:
        recommendation = f"{data['child_name']} is making good progress. Encourage them to keep their streak going!"

    subj = data["subjects_breakdown"]
    total_for_chart = max(sum(subj.values()), 1)

    def bar(count: int, color: str) -> str:
        pct = round(count / total_for_chart * 100)
        return f'<div class="bar" style="width:{pct}%;background:{color}"></div>'

    weekly = data.get("weekly_data", [])
    max_day = max((d["questions"] for d in weekly), default=1) or 1
    day_bars = ""
    for d in weekly:
        h = round(d["questions"] / max_day * 80)
        day_bars += f"""
        <div class="day-col">
          <div class="day-bar" style="height:{h}px;background:#4285F4"></div>
          <div class="day-label">{d['day']}</div>
          <div class="day-count">{d['questions']}</div>
        </div>"""

    quiz_rows = ""
    for q in data["quiz_scores"][:5]:
        pct = round(q["score"] / max(q["total"], 1) * 100)
        color = "#34A853" if pct >= 80 else "#FBBC05" if pct >= 50 else "#EA4335"
        quiz_rows += f"""<tr>
          <td>{q['date']}</td>
          <td>{q['score']}/{q['total']}</td>
          <td><span style="color:{color};font-weight:700">{pct}%</span></td>
        </tr>"""

    topics_html = "".join(
        f'<span class="topic-chip">{t}</span>' for t in data["recent_topics"]
    )

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>VoiceGuru — {data['child_name']}'s Progress</title>
<style>
  *{{box-sizing:border-box;margin:0;padding:0}}
  body{{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
        background:#F8F9FA;color:#202124;min-height:100vh}}
  .header{{background:linear-gradient(135deg,#4285F4,#3367D6);color:#fff;
           padding:28px 20px 20px;text-align:center}}
  .header h1{{font-size:26px;font-weight:700;margin-bottom:4px}}
  .header p{{font-size:14px;opacity:.85}}
  .badge-row{{display:flex;justify-content:center;gap:8px;margin-top:12px;flex-wrap:wrap}}
  .badge{{background:rgba(255,255,255,.2);border-radius:20px;padding:4px 12px;
          font-size:12px;font-weight:600}}
  .content{{max-width:600px;margin:0 auto;padding:16px}}
  .card{{background:#fff;border-radius:16px;padding:20px;margin-bottom:16px;
         box-shadow:0 2px 12px rgba(0,0,0,.07)}}
  .card h2{{font-size:16px;font-weight:700;color:#202124;margin-bottom:14px;
            display:flex;align-items:center;gap:8px}}
  .stat-row{{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-bottom:16px}}
  .stat{{background:#fff;border-radius:14px;padding:14px 10px;text-align:center;
         box-shadow:0 2px 10px rgba(0,0,0,.07)}}
  .stat-num{{font-size:28px;font-weight:800;color:#4285F4}}
  .stat-label{{font-size:11px;color:#5F6368;margin-top:3px}}
  .subj-row{{margin-bottom:10px}}
  .subj-label{{font-size:13px;color:#5F6368;margin-bottom:4px;
               display:flex;justify-content:space-between}}
  .bar-bg{{background:#F1F3F4;border-radius:6px;height:10px;overflow:hidden}}
  .bar{{height:10px;border-radius:6px;transition:width .6s ease}}
  .chart{{display:flex;align-items:flex-end;gap:6px;height:100px;
          padding:0 4px;border-bottom:2px solid #E8EAED}}
  .day-col{{flex:1;display:flex;flex-direction:column;align-items:center;gap:3px}}
  .day-bar{{border-radius:4px 4px 0 0;min-height:4px;width:100%;transition:height .5s}}
  .day-label{{font-size:10px;color:#5F6368;margin-top:4px}}
  .day-count{{font-size:10px;color:#4285F4;font-weight:700}}
  .topic-chip{{display:inline-block;background:#E8F0FE;color:#4285F4;border-radius:20px;
               padding:4px 12px;font-size:12px;font-weight:600;margin:3px}}
  table{{width:100%;border-collapse:collapse;font-size:13px}}
  th{{color:#5F6368;font-weight:600;text-align:left;padding:6px 0;
      border-bottom:1px solid #E8EAED}}
  td{{padding:8px 0;border-bottom:1px solid #F1F3F4}}
  .rec-box{{background:linear-gradient(135deg,#E8F5E9,#F1F8E9);border-radius:12px;
             padding:16px;border-left:4px solid #34A853}}
  .rec-box p{{font-size:14px;line-height:1.6;color:#202124}}
  .footer{{text-align:center;padding:20px;color:#9AA0A6;font-size:12px}}
  .flame{{font-size:22px}}
  @media(max-width:400px){{.stat-num{{font-size:22px}}}}
</style>
</head>
<body>
<div class="header">
  <h1>🦉 {data['child_name']}'s Learning Report</h1>
  <p>Class {data['grade']} · Powered by VoiceGuru AI Tutor</p>
  <div class="badge-row">
    <span class="badge">🔥 {data['streak_days']}-day streak</span>
    <span class="badge">📚 {data['total_questions']} total questions</span>
  </div>
</div>

<div class="content">
  <!-- Stats -->
  <div class="stat-row">
    <div class="stat">
      <div class="stat-num">{data['streak_days']}</div>
      <div class="stat-label">Day Streak 🔥</div>
    </div>
    <div class="stat">
      <div class="stat-num">{data['this_week_questions']}</div>
      <div class="stat-label">This Week 📖</div>
    </div>
    <div class="stat">
      <div class="stat-num">{data['total_questions']}</div>
      <div class="stat-label">All Time 🏆</div>
    </div>
  </div>

  <!-- Weekly Activity -->
  <div class="card">
    <h2>📅 This Week's Activity</h2>
    <div class="chart">{day_bars}</div>
  </div>

  <!-- Subject Breakdown -->
  <div class="card">
    <h2>📊 Subject Breakdown</h2>
    <div class="subj-row">
      <div class="subj-label"><span>📐 Math</span><span>{subj.get('math',0)}</span></div>
      <div class="bar-bg">{bar(subj.get('math',0),'#4285F4')}</div>
    </div>
    <div class="subj-row" style="margin-top:10px">
      <div class="subj-label"><span>🔬 Science</span><span>{subj.get('science',0)}</span></div>
      <div class="bar-bg">{bar(subj.get('science',0),'#34A853')}</div>
    </div>
    <div class="subj-row" style="margin-top:10px">
      <div class="subj-label"><span>🗺️ Social Studies</span><span>{subj.get('social_studies',0)}</span></div>
      <div class="bar-bg">{bar(subj.get('social_studies',0),'#FBBC05')}</div>
    </div>
    <div class="subj-row" style="margin-top:10px">
      <div class="subj-label"><span>💡 Other</span><span>{subj.get('other',0)}</span></div>
      <div class="bar-bg">{bar(subj.get('other',0),'#EA4335')}</div>
    </div>
  </div>

  <!-- Recent Topics -->
  {'<div class="card"><h2>🧠 Recent Topics</h2><div>' + topics_html + '</div></div>' if topics_html else ''}

  <!-- Quiz Scores -->
  {'<div class="card"><h2>📝 Quiz Performance</h2><table><tr><th>Date</th><th>Score</th><th>%</th></tr>' + quiz_rows + '</table></div>' if quiz_rows else ''}

  <!-- AI Recommendation -->
  <div class="card">
    <h2>💬 Teacher Recommendation</h2>
    <div class="rec-box">
      <p>{recommendation}</p>
    </div>
  </div>

  <!-- Strengths & Attention -->
  <div class="card">
    <h2>⭐ Strengths</h2>
    <div>{''.join(f'<span class="topic-chip" style="background:#E8F5E9;color:#34A853">{s}</span>' for s in data['strengths'])}</div>
    <h2 style="margin-top:14px">🎯 Practice More</h2>
    <div>{''.join(f'<span class="topic-chip" style="background:#FFF8E1;color:#F57F17">{a}</span>' for a in data['areas_needing_attention'])}</div>
  </div>
</div>

<div class="footer">
  Generated by VoiceGuru AI Tutor · voiceguru.app<br>
  Share this link with your child's teacher to track progress
</div>
</body>
</html>"""
    return HTMLResponse(content=html)


@app.get("/status")
def status() -> dict:
    # The endpoint is intentionally stable for frontend health checks.
    if GEMINI_API_KEY:
        return {"status": "ok", "gemini": "connected"}
    return {"status": "ok", "gemini": "not_configured"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
