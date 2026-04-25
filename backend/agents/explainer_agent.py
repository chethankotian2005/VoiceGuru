from __future__ import annotations

import asyncio
import json
import os
from typing import Any

from dotenv import load_dotenv

try:
    from google import genai
except Exception:  # pragma: no cover - graceful fallback when SDK is unavailable
    genai = None


load_dotenv()

DEFAULT_MODEL = "gemini-2.5-flash-lite"
FALLBACK_EXPLANATION = "I had trouble understanding that. Can you ask your question again?"

VALID_DIAGRAM_TYPES = {
    "ray_diagram",
    "food_chain",
    "water_cycle",
    "number_line",
    "geometric_shape",
    "human_body",
    "solar_system",
    "circuit",
    "bar_chart",
    "none",
}


def _fallback_response(raw_text: str | None = None) -> dict[str, Any]:
    """Return a safe structured response when JSON parsing fails or an error occurs."""
    return {
        "explanation": raw_text or FALLBACK_EXPLANATION,
        "needs_diagram": False,
        "diagram_description": None,
        "diagram_type": "none",
        "youtube_search_query": None,
        "key_terms": [],
    }

def _get_client() -> genai.Client | None:
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if api_key and genai is not None:
        return genai.Client(api_key=api_key)
    return None


def _build_system_prompt(grade: int, language: str, syllabus_context: str) -> str:
    if 1 <= grade <= 4:
        grade_search_context = 'Append "for kids primary school" to the query.'
    elif 5 <= grade <= 6:
        grade_search_context = 'Append "for class 5 6 students explanation" to the query.'
    elif 7 <= grade <= 8:
        grade_search_context = 'Append "class 7 8 cbse explained" to the query.'
    else:
        grade_search_context = 'Append "class 9 10 board exam explained" to the query.'

    return (
        f"You are VoiceGuru, a friendly AI tutor for Karnataka State Board students. "
        f"You are talking to a Class {grade} student.\n\n"
        "You MUST respond with a valid JSON object and nothing else — no markdown, "
        "no code fences, no trailing text.\n\n"
        "JSON SCHEMA (follow exactly):\n"
        "{\n"
        '  "explanation": "child-friendly text explanation",\n'
        '  "needs_diagram": true or false,\n'
        '  "diagram_description": "describe what diagram would help, or null",\n'
        '  "diagram_type": "one of: ray_diagram | food_chain | water_cycle | '
        "number_line | geometric_shape | human_body | solar_system | circuit | "
        'bar_chart | none",\n'
        '  "youtube_search_query": "specific educational search query for YouTube, or null",\n'
        '  "key_terms": ["term1", "term2"]\n'
        "}\n\n"
        "RULES:\n"
        f"1. Write the explanation ONLY in {language}. Every word of the explanation "
        f"must be in {language}.\n"
        f"2. Keep the explanation under 120 words. It will be read aloud to a child.\n"
        f"3. Use simple words a Class {grade} child understands.\n"
        "4. Use examples from daily life in Bangalore/Karnataka (local bus routes, "
        "Lalbagh, Vidhana Soudha, local fruits like mango and jackfruit, "
        "Karnataka festivals like Dasara, etc.).\n"
        "5. Sound warm and encouraging, like a friendly teacher.\n"
        "6. Never use markdown, bullet points, or special characters in the explanation text.\n"
        "7. Set needs_diagram to true for ANY visual concept:\n"
        "   - Science diagrams: photosynthesis, digestion, light scattering, "
        "refraction, reflection, solar system, circuits, cell structure\n"
        "   - Math geometry: triangles, circles, angles, coordinate planes\n"
        "   - Ecology: food chains, water cycles, life cycles, ecosystems\n"
        "   - Human body: skeleton, organs, nervous system\n"
        "8. ALWAYS provide a youtube_search_query. Never set it to null. "
        f"Make it a specific, educational search query. {grade_search_context}\n"
        "9. For diagram_type, you MUST pick an exact match from the allowed list: [ray_diagram, food_chain, water_cycle, number_line, geometric_shape, human_body, solar_system, circuit, bar_chart]. "
        'CRITICAL: If the topic does NOT perfectly match one of these specific diagrams, you MUST rely on the youtube videos instead and set diagram_type to "none" and needs_diagram to false. Do not hallucinate diagram_type.\n'
        "10. Include 2-5 key_terms that are the most important concepts in the answer.\n"
        "11. JSON keys must be in English. Only the explanation text value and "
        "diagram_description value should be in the requested language.\n\n"
        f"SYLLABUS CONTEXT:\n{syllabus_context}"
    )


def _parse_json_response(raw_text: str) -> dict[str, Any]:
    """Attempt to parse a JSON response from the model, with safe fallback."""
    text = raw_text.strip()

    # Strip markdown code fences if model wraps response
    if text.startswith("```"):
        # Remove opening fence (```json or ```)
        first_newline = text.index("\n") if "\n" in text else len(text)
        text = text[first_newline + 1 :]
        # Remove closing fence
        if text.endswith("```"):
            text = text[: -3].strip()

    try:
        parsed = json.loads(text)
    except (json.JSONDecodeError, ValueError):
        return _fallback_response(raw_text)

    if not isinstance(parsed, dict):
        return _fallback_response(raw_text)

    # Validate and normalise fields
    explanation = str(parsed.get("explanation", "")).strip()
    if not explanation:
        explanation = raw_text

    needs_diagram = bool(parsed.get("needs_diagram", False))

    diagram_description = parsed.get("diagram_description")
    if diagram_description is not None:
        diagram_description = str(diagram_description).strip() or None

    diagram_type = str(parsed.get("diagram_type", "none")).strip().lower()
    if diagram_type not in VALID_DIAGRAM_TYPES:
        diagram_type = "none"

    youtube_search_query = parsed.get("youtube_search_query")
    if youtube_search_query is not None:
        youtube_search_query = str(youtube_search_query).strip() or None

    raw_terms = parsed.get("key_terms", [])
    if isinstance(raw_terms, list):
        key_terms = [str(t).strip() for t in raw_terms if str(t).strip()]
    else:
        key_terms = []

    return {
        "explanation": explanation,
        "needs_diagram": needs_diagram,
        "diagram_description": diagram_description,
        "diagram_type": diagram_type,
        "youtube_search_query": youtube_search_query,
        "key_terms": key_terms,
    }


async def explain(
    question: str,
    subject: str,
    grade: int,
    language: str,
    syllabus_context: str,
) -> dict[str, Any]:
    client = _get_client()
    if client is None:
        return _fallback_response()

    try:
        prompt = (
            f"Question: {question.strip() or 'N/A'}\n"
            f"Subject: {subject.strip() or 'General'}\n"
            "Explain this clearly for the child. Respond with the JSON object only."
        )

        response = await asyncio.to_thread(
            client.models.generate_content,
            model=DEFAULT_MODEL,
            contents=prompt,
            config=genai.types.GenerateContentConfig(
                system_instruction=_build_system_prompt(
                    grade=grade,
                    language=language,
                    syllabus_context=syllabus_context,
                ),
                response_mime_type="application/json"
            )
        )
        raw_text = getattr(response, "text", "")
        if not raw_text or not raw_text.strip():
            return _fallback_response()

        return _parse_json_response(raw_text)
    except Exception as e:
        import traceback
        traceback_str = traceback.format_exc()
        traceback.print_exc()

        # Check for free tier rate limits
        if "429" in str(e) or "Quota exceeded" in str(e) or "ResourceExhausted" in str(e):
             return _fallback_response("I'm receiving too many questions right now! Please wait a minute and try asking again.")

        return _fallback_response()


class ExplainerAgent:
    """Creates grade-aware explanations in the requested language."""

    async def explain(
        self,
        question: str,
        subject: str,
        grade: int,
        language: str,
        syllabus_context: str,
    ) -> dict[str, Any]:
        return await explain(
            question=question,
            subject=subject,
            grade=grade,
            language=language,
            syllabus_context=syllabus_context,
        )

    def run(self, question: str, subject: str, grade: int, language: str, syllabus_context: str = "") -> dict[str, Any]:
        return asyncio.run(
            explain(
                question=question,
                subject=subject,
                grade=grade,
                language=language,
                syllabus_context=syllabus_context,
            )
        )
