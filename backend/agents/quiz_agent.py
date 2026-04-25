from __future__ import annotations

import asyncio
import json
import os
from typing import Any

from dotenv import load_dotenv

try:
    from google import genai
except Exception:  # pragma: no cover
    genai = None

load_dotenv()

DEFAULT_MODEL = "gemini-2.5-flash"

def _get_client() -> genai.Client | None:
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if api_key and genai is not None:
        return genai.Client(api_key=api_key)
    return None

async def generate_quiz(
    grade: int,
    language: str,
    topics: list[str],
    num_questions: int = 5
) -> list[dict[str, Any]]:
    client = _get_client()
    if client is None:
        return []

    topics_str = ", ".join(topics) if topics else f"General Grade {grade} Karnataka State Board Syllabus"

    prompt = f"""Generate {num_questions} multiple choice questions for a Class {grade} Karnataka State Board student.
Base questions on these topics: {topics_str}.
Each question must have exactly 4 options (A, B, C, D).
One correct answer.
Questions MUST be entirely in {language}.
Difficulty: appropriate for Class {grade}.

Return ONLY a valid JSON array and nothing else — no markdown formatting, no code blocks.

JSON SCHEMA (follow exactly):
[
  {{
    "question": "question text",
    "options": ["A. option1", "B. option2", "C. option3", "D. option4"],
    "correct": "A",
    "explanation": "brief explanation why correct",
    "subject": "math|science|social_studies",
    "topic": "topic name"
  }}
]"""

    try:
        response = await asyncio.to_thread(
            client.models.generate_content,
            model=DEFAULT_MODEL,
            contents=prompt,
            config=genai.types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.7,
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

        parsed = json.loads(raw_text)
        if isinstance(parsed, list):
            return parsed
        return []
    except Exception as e:
        import traceback
        traceback.print_exc()
        return []
