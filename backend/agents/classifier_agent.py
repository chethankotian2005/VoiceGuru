from __future__ import annotations

import asyncio
import json
import os
import re
from typing import Any

from dotenv import load_dotenv

try:
    from google import genai
except Exception:  # pragma: no cover - graceful fallback when SDK is unavailable
    genai = None

load_dotenv()


SAFE_DEFAULTS = {
    "subject": "general",
    "estimated_grade": 6,
    "complexity": "medium",
    "detected_language": "english",
}

SYSTEM_PROMPT = (
    "You are a classifier for Karnataka State Board student questions. Classify the question and return "
    "ONLY a JSON object with keys: subject, estimated_grade, complexity, detected_language. No other text.\n"
    "IMPORTANT: Detect the actual language of the input text.\n"
    "If the text contains Kannada script (ಕನ್ನಡ), return 'kannada'.\n"
    "If Hindi script (हिंदी), return 'hindi'.\n"
    "If Tamil script (தமிழ்), return 'tamil'.\n"
    "If English or mixed, return 'english'.\n"
    "This detection must be based on the ACTUAL INPUT LANGUAGE, not the user's preferred language."
)

SUBJECT_ALIASES = {
    "math": "math",
    "mathematics": "math",
    "science": "science",
    "social": "social_studies",
    "social_studies": "social_studies",
    "social studies": "social_studies",
    "social_science": "social_studies",
    "social science": "social_studies",
    "language": "language",
    "general": "general",
}

COMPLEXITY_ALIASES = {
    "simple": "simple",
    "easy": "simple",
    "medium": "medium",
    "moderate": "medium",
    "complex": "complex",
    "hard": "complex",
}

LANGUAGE_ALIASES = {
    "kannada": "kannada",
    "hindi": "hindi",
    "tamil": "tamil",
    "english": "english",
}


def _get_client() -> genai.Client | None:
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if api_key and genai is not None:
        return genai.Client(api_key=api_key)
    return None

def _extract_text(response: Any) -> str:
    text = getattr(response, "text", "")
    if text:
        return str(text).strip()

    try:
        candidates = getattr(response, "candidates", []) or []
        if not candidates:
            return ""
        parts = candidates[0].content.parts
        chunks = [getattr(part, "text", "") for part in parts]
        return "".join(chunks).strip()
    except Exception:
        return ""


def _parse_json_blob(raw_text: str) -> dict[str, Any]:
    text = (raw_text or "").strip()
    if not text:
        return {}

    fenced_match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", text, flags=re.DOTALL | re.IGNORECASE)
    if fenced_match:
        text = fenced_match.group(1)

    if not text.startswith("{"):
        brace_match = re.search(r"\{.*\}", text, flags=re.DOTALL)
        if brace_match:
            text = brace_match.group(0)

    try:
        payload = json.loads(text)
        if isinstance(payload, dict):
            return payload
    except Exception:
        return {}
    return {}


def _clamp_grade(value: Any) -> int:
    try:
        grade = int(value)
    except Exception:
        return SAFE_DEFAULTS["estimated_grade"]
    return min(10, max(1, grade))


def _normalize_classification(payload: dict[str, Any]) -> dict[str, Any]:
    subject_raw = str(payload.get("subject", SAFE_DEFAULTS["subject"]))
    complexity_raw = str(payload.get("complexity", SAFE_DEFAULTS["complexity"]))
    language_raw = str(payload.get("detected_language", SAFE_DEFAULTS["detected_language"]))

    subject = SUBJECT_ALIASES.get(subject_raw.strip().lower(), SAFE_DEFAULTS["subject"])
    complexity = COMPLEXITY_ALIASES.get(complexity_raw.strip().lower(), SAFE_DEFAULTS["complexity"])
    detected_language = LANGUAGE_ALIASES.get(language_raw.strip().lower(), SAFE_DEFAULTS["detected_language"])

    return {
        "subject": subject,
        "estimated_grade": _clamp_grade(payload.get("estimated_grade")),
        "complexity": complexity,
        "detected_language": detected_language,
    }


async def classify_question(question: str) -> dict:
    try:
        normalized_question = (question or "").strip()
        if not normalized_question:
            return dict(SAFE_DEFAULTS)

        client = _get_client()
        if client is None:
            return dict(SAFE_DEFAULTS)

        response = await asyncio.to_thread(
            client.models.generate_content,
            model="gemini-2.5-flash-lite",
            contents=normalized_question,
            config=genai.types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT,
            )
        )
        raw_text = _extract_text(response)
        payload = _parse_json_blob(raw_text)
        if not payload:
            return dict(SAFE_DEFAULTS)

        return _normalize_classification(payload)
    except Exception:
        return dict(SAFE_DEFAULTS)
