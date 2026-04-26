from __future__ import annotations

import asyncio

from agents.classifier_agent import classify_question
from agents.explainer_agent import explain
from agents.simplifier_agent import simplify
from syllabus_context import get_syllabus_context


def _safe_dict(message: str, extra: dict | None = None) -> dict:
    payload = {"explanation": message}
    if extra:
        payload.update(extra)
    return payload


async def run_voiceguru_pipeline(
    question: str,
    language: str = "english",
    grade: int | None = None,
    child_id: str = "unknown",
    conversation_context: str = "",
    board: str = "Karnataka State Board",
    difficulty: str = "medium",
) -> dict:
    try:
        classification = await classify_question(question)
        subject = classification.get("subject", "general")
        estimated_grade = classification.get("estimated_grade", 6)
        complexity = classification.get("complexity", "medium")
        detected_language = classification.get("detected_language", "english")

        grade_used = grade if grade is not None else estimated_grade
        # Always use detected language from actual input
        # Only fall back to request language if detection fails
        language_used = detected_language if detected_language else language

        syllabus_context = await get_syllabus_context(grade=grade_used, subject=subject, board=board)
        explainer_result = await explain(
            question=question,
            subject=subject,
            grade=grade_used,
            language=language_used,
            syllabus_context=syllabus_context,
            conversation_context=conversation_context,
            difficulty=difficulty,
        )
        return {
            "explanation": explainer_result.get("explanation", ""),
            "subject": subject,
            "grade_used": grade_used,
            "language": language_used,
            "requested_language": language,
            "complexity": complexity,
            "agent_trace": ["Classifier ✓", "Explainer ✓"],
            "child_id": child_id,
            "needs_diagram": explainer_result.get("needs_diagram", False),
            "diagram_description": explainer_result.get("diagram_description"),
            "diagram_type": explainer_result.get("diagram_type", "none"),
            "youtube_search_query": explainer_result.get("youtube_search_query"),
            "key_terms": explainer_result.get("key_terms", []),
        }
    except Exception as e:
        import traceback
        traceback.print_exc()

        msg = "I had trouble understanding that. Can you ask your question again?"
        if "429" in str(e) or "Quota exceeded" in str(e) or "ResourceExhausted" in str(e):
             msg = "I'm receiving too many questions right now! Please wait a minute and try asking again."

        with open('error.log', 'w') as f:
            traceback.print_exc(file=f)
        return _safe_dict(
            msg,
            {
                "subject": "general",
                "grade_used": grade if grade is not None else 6,
                "language": language or "english",
                "complexity": "unknown",
                "agent_trace": ["Classifier", "Explainer"],
                "child_id": child_id,
            },
        )


async def run_simplify_pipeline(
    original_question: str,
    original_explanation: str,
    language: str,
    grade: int,
) -> dict:
    try:
        result = await simplify(
            original_question=original_question,
            original_explanation=original_explanation,
            grade=grade,
            language=language,
        )
        return {
            "simplified_explanation": result,
            "agent_trace": ["Simplifier ✓"],
            "explanation": result,
        }
    except Exception:
        return _safe_dict(
            "I could not simplify this right now, but please try again in a moment.",
            {
                "simplified_explanation": "I could not simplify this right now, but please try again in a moment.",
                "agent_trace": ["Simplifier"],
            },
        )


def run_ask_pipeline(text: str, language: str, grade: int, child_id: str = "unknown", conversation_context: str = "", board: str = "Karnataka State Board", difficulty: str = "medium") -> dict:
    return asyncio.run(
        run_voiceguru_pipeline(
            question=text,
            language=language,
            grade=grade,
            child_id=child_id,
            conversation_context=conversation_context,
            board=board,
            difficulty=difficulty,
        )
    )


def run_simplify_pipeline_sync(original_explanation: str, language: str, grade: int) -> dict:
    return asyncio.run(
        run_simplify_pipeline_async(
            original_question="",
            original_explanation=original_explanation,
            language=language,
            grade=grade,
        )
    )


async def run_simplify_pipeline_async(
    original_question: str,
    original_explanation: str,
    language: str,
    grade: int,
) -> dict:
    return await run_simplify_pipeline(
        original_question=original_question,
        original_explanation=original_explanation,
        language=language,
        grade=grade,
    )
