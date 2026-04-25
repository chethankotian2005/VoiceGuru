from __future__ import annotations

import asyncio
import os

from dotenv import load_dotenv

try:
    from google import genai
except Exception:  # pragma: no cover - graceful fallback when SDK is unavailable
    genai = None


load_dotenv()

DEFAULT_MODEL = "gemini-2.5-flash-lite"

SYSTEM_PROMPT_TEMPLATE = (
    "You are VoiceGuru. A child did not understand your previous explanation. Make it MUCH simpler.\n\n"
    "RULES:\n"
    "- Respond ONLY in {language}\n"
    "- Use even simpler words than before\n"
    "- Use ONE relatable example from daily life\n"
    "- Maximum 80 words -- very short and clear\n"
    "- Start with: 'Let me explain differently...'\n"
    "- No markdown, no bullet points"
)

FALLBACK_RESPONSE = (
    "Let me explain differently... I will simplify this in a clearer way."
)


def _get_client() -> genai.Client | None:
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if api_key and genai is not None:
        return genai.Client(api_key=api_key)
    return None


async def simplify(
    original_question: str,
    original_explanation: str,
    grade: int,
    language: str,
) -> str:
    client = _get_client()
    if client is None:
        return FALLBACK_RESPONSE

    try:
        prompt = (
            f"Original question: {original_question.strip() or 'N/A'}\n"
            f"Original explanation: {original_explanation.strip() or 'N/A'}\n"
            f"Grade: {grade}\n"
            f"Language: {language}\n"
            "Make the explanation much simpler for the child."
        )

        response = await asyncio.to_thread(
            client.models.generate_content,
            model=DEFAULT_MODEL,
            contents=prompt,
            config=genai.types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT_TEMPLATE.format(language=language),
            )
        )
        final_response = str(getattr(response, "text", "")).strip()
        return final_response or FALLBACK_RESPONSE
    except Exception:
        return FALLBACK_RESPONSE


class SimplifierAgent:
    """Simplifies an explanation for young learners."""

    async def simplify(
        self,
        original_question: str,
        original_explanation: str,
        grade: int,
        language: str,
    ) -> str:
        return await simplify(
            original_question=original_question,
            original_explanation=original_explanation,
            grade=grade,
            language=language,
        )

    def run(self, explanation: str, grade: int, language: str) -> str:
        return asyncio.run(
            simplify(
                original_question="",
                original_explanation=explanation,
                grade=grade,
                language=language,
            )
        )
