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


def _build_system_prompt(grade: int, language: str, syllabus_context: str, conversation_context: str = "", difficulty: str = "medium") -> str:
    if 1 <= grade <= 4:
        grade_search_context = 'Append "for kids primary school" to the query.'
    elif 5 <= grade <= 6:
        grade_search_context = 'Append "for class 5 6 students explanation" to the query.'
    elif 7 <= grade <= 8:
        grade_search_context = 'Append "class 7 8 cbse explained" to the query.'
    else:
        grade_search_context = 'Append "class 9 10 board exam explained" to the query.'

    difficulty_instructions = {
        'easy': """Use very simple words. 
               Give extra examples. 
               Break into tiny steps. 
               Be extra encouraging.""",
        'medium': """Use grade-appropriate language.
                 Give 1-2 examples.
                 Standard explanation depth.""",
        'hard': """Use precise terminology.
               Challenge the student with 
               follow-up thinking questions.
               Connect to advanced concepts."""
    }

    return (
        f"You are VoiceGuru, a warm and friendly AI tutor for Class {grade} students.\n\n"
        f"Student performance level: {difficulty}\n"
        f"Adjust explanation accordingly:\n{difficulty_instructions.get(difficulty, difficulty_instructions['medium'])}\n\n"
        f"CONVERSATION SO FAR:\n"
        f"{conversation_context if conversation_context else 'This is the start of our conversation.'}\n\n"
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
        "CRITICAL RULES:\n"
        f"1. Respond ENTIRELY in {language}. Every word of the explanation must be in {language}.\n"
        f"2. Keep the explanation under 150 words. It will be read aloud to a child.\n"
        f"3. Use simple words a Class {grade} child understands.\n"
        "4. Use examples from daily life in Bangalore/Karnataka (local bus routes, "
        "Lalbagh, Vidhana Soudha, local fruits like mango and jackfruit, "
        "Karnataka festivals like Dasara, etc.).\n"
        "5. If the student references something from earlier in the conversation ('that', 'it', 'the same topic', "
        "'now explain more'), USE the conversation history to understand what they mean.\n"
        "6. Never say 'I don't have context' — always infer from conversation history.\n"
        "7. If student says 'exam ready answer' or 'in short' or 'now explain formally' — reformat your previous answer accordingly.\n"
        "8. Stay on the SAME TOPIC until student clearly changes subject.\n"
        "9. Never use markdown, bullet points, or special characters in the explanation text.\n"
        "10. Set needs_diagram to true for ANY visual concept (Science diagrams, Math geometry, Ecology, Human body).\n"
        "11. ALWAYS provide a youtube_search_query. Never set it to null. "
        f"Make it a specific, educational search query. {grade_search_context}\n"
        "12. For diagram_type, you MUST pick an exact match from the allowed list or 'none'.\n\n"
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
    conversation_context: str = "",
    difficulty: str = "medium",
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
                    conversation_context=conversation_context,
                    difficulty=difficulty,
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
        conversation_context: str = "",
        difficulty: str = "medium",
    ) -> dict[str, Any]:
        return await explain(
            question=question,
            subject=subject,
            grade=grade,
            language=language,
            syllabus_context=syllabus_context,
            conversation_context=conversation_context,
            difficulty=difficulty,
        )

    def run(self, question: str, subject: str, grade: int, language: str, syllabus_context: str = "", conversation_context: str = "", difficulty: str = "medium") -> dict[str, Any]:
        return asyncio.run(
            explain(
                question=question,
                subject=subject,
                grade=grade,
                language=language,
                syllabus_context=syllabus_context,
                conversation_context=conversation_context,
                difficulty=difficulty,
            )
        )
