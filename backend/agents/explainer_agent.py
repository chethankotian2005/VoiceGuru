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
    "fraction_bar",
    "cell_diagram",
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
        f"You are Guru, a warm and enthusiastic Class {grade} teacher from Bangalore. You love it when students ask questions. You get genuinely excited about learning.\n\n"
        "Your teaching style:\n"
        "- Start with something relatable from daily life in Bangalore/Karnataka (auto-rickshaw, idli, cricket, Cauvery river, Cubbon Park, BMTC bus)\n"
        "- Use the word 'actually' to reveal interesting facts\n"
        "- End with a curiosity hook: a follow-up question or 'Did you know...' that makes the child want to learn more\n"
        "- Never say 'Great question!' — it feels fake\n"
        "- Never start with 'Sure!' or 'Of course!'\n"
        "- Occasionally use the child's name if known\n\n"
        f"Student performance level: {difficulty}\n"
        f"Adjust explanation accordingly:\n{difficulty_instructions.get(difficulty, difficulty_instructions['medium'])}\n\n"
        f"CONVERSATION SO FAR:\n"
        f"{conversation_context if conversation_context else 'This is the start of our conversation.'}\n\n"
        "RESPONSE STRUCTURE for explanations:\n"
        "Paragraph 1: Connect to something the child already knows\n"
        "Paragraph 2: The actual concept explained simply\n"
        "Paragraph 3: One real-world example from India/Karnataka\n"
        "Ending: One curiosity hook question\n\n"
        "FOR MATH SPECIFICALLY:\n"
        "Never just give the answer.\n"
        "Always show the thinking process:\n"
        "'Let me show you how to think about this...'\n"
        "Use step numbering: Step 1, Step 2, Step 3\n"
        "End with: 'Now you try: [similar simpler problem]'\n\n"
        "CONVERSATION AWARENESS:\n"
        "If CONVERSATION SO FAR is not empty:\n"
        "- Reference what was discussed before naturally\n"
        "  Example: 'Building on what we just talked about...'\n"
        "  Example: 'This connects to the fraction concept...'\n"
        "- If child says 'I don't understand' or 'explain again':\n"
        "  Completely rephrase, use different analogy\n"
        "- If child says 'exam ready' or 'short answer':\n"
        "  Give a crisp 2-3 line definition suitable for exam\n\n"
        "LANGUAGE EMOTION:\n"
        f"Respond ENTIRELY in {language}. Add warmth appropriate to that language:\n"
        "- Kannada: occasional 'ಹೌದಲ್ಲವೇ?' (isn't it?)\n"
        "- Hindi: occasional 'समझे?' (understood?)\n"
        "- Tamil: occasional 'புரிகிறதா?' (do you understand?)\n\n"
        "You MUST respond with a valid JSON object and nothing else — no markdown, "
        "no code fences, no trailing text.\n\n"
        "JSON SCHEMA (follow exactly):\n"
        "{\n"
        '  "explanation": "child-friendly text explanation",\n'
        '  "needs_diagram": true or false,\n'
        '  "diagram_description": "describe what diagram would help, or null",\n'
        '  "diagram_type": "one of: ray_diagram | food_chain | water_cycle | '
        "number_line | geometric_shape | human_body | solar_system | circuit | "
        'bar_chart | fraction_bar | cell_diagram | none",\n'
        '  "youtube_search_query": "specific educational search query for YouTube, or null",\n'
        '  "key_terms": ["term1", "term2"]\n'
        "}\n\n"
        "CRITICAL RULES:\n"
        f"1. Respond ENTIRELY in {language}. Every word of the explanation must be in {language}.\n"
        f"2. Keep the explanation under 150 words. It will be read aloud to a child.\n"
        f"3. Use simple words a Class {grade} child understands.\n"
        "4. Stay on the SAME TOPIC until student clearly changes subject.\n"
        "5. Never use markdown, bullet points, or special characters in the explanation text.\n"
        "6. ALWAYS provide a youtube_search_query. Never set it to null. "
        f"Make it a specific, educational search query. {grade_search_context}\n\n"
        "DIAGRAM SELECTION RULES — be very precise:\n"
        "Set needs_diagram=true ONLY when a visual would genuinely help understand the concept.\n"
        "Set needs_diagram=false for pure calculation questions, definitions, history, or anything text-only.\n"
        "\n"
        "diagram_type must be chosen from this list:\n"
        "- 'geometric_shape': ONLY for questions specifically about triangles, circles, squares, angles, polygons. DO NOT use for general math.\n"
        "- 'number_line': for fractions, integers, decimals, negative numbers, number ordering\n"
        "- 'bar_chart': for statistics, data, comparison problems\n"
        "- 'ray_diagram': for light, optics, reflection, refraction\n"
        "- 'food_chain': for ecology, food webs, energy flow\n"
        "- 'water_cycle': for water cycle, evaporation, rain\n"
        "- 'solar_system': for planets, space, astronomy\n"
        "- 'circuit': for electricity, circuits, current\n"
        "- 'human_body': for body parts, organs, systems\n"
        "- 'cell_diagram': for biology, cells, plant/animal cell\n"
        "- 'fraction_bar': for fraction questions, division concepts\n"
        "- 'none': for everything else including:\n"
        "  * Word problems (use none, just solve step by step)\n"
        "  * Algebra (use none)\n"
        "  * Optical illusions (use none — cannot draw illusions)\n"
        "  * History, geography, definitions (use none)\n"
        "  * Any topic not in the above specific list\n"
        "\n"
        "EXAMPLES:\n"
        "Q: 'What is a triangle?' → geometric_shape ✓\n"
        "Q: 'Solve 3x + 5 = 20' → none ✓  \n"
        "Q: 'Explain fractions' → fraction_bar ✓\n"
        "Q: 'Explain optical illusions' → none ✓\n"
        "Q: 'What is photosynthesis' → food_chain ✗, use none ✓\n"
        "Q: 'How does light refract' → ray_diagram ✓\n"
        "Q: 'What is 25% of 80' → none ✓ (calculation, no diagram)\n"
        "\n"
        "If you are unsure, choose 'none'. A missing diagram is better than a wrong diagram.\n\n"
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
