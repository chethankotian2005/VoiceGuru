from __future__ import annotations
import asyncio
import os
from typing import Optional
from google import genai
from dotenv import load_dotenv

load_dotenv()

# Cache syllabus context to avoid repeated API calls
_syllabus_cache = {}

SUBJECT_ALIASES = {
    "math": "mathematics",
    "maths": "mathematics",
    "mathematics": "mathematics",
    "science": "science",
    "social": "social studies",
    "social studies": "social studies",
    "social science": "social studies",
}

def _normalize_subject(subject: str) -> str:
    key = (subject or "").strip().lower()
    return SUBJECT_ALIASES.get(key, key)

async def get_syllabus_context(
    grade: int, 
    subject: str, 
    board: str = "Karnataka State Board"
) -> str:
    normalized_subject = _normalize_subject(subject)
    cache_key = f"{board}_{grade}_{normalized_subject}"
    
    if cache_key in _syllabus_cache:
        return _syllabus_cache[cache_key]
    
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if not api_key:
        return _get_static_context(grade, normalized_subject)

    try:
        client = genai.Client(api_key=api_key)
        
        prompt = f"""You are an expert in {board} curriculum.

List the KEY TOPICS and CONCEPTS taught in 
Class {grade} {normalized_subject} under {board}.

Format as a concise reference (max 200 words):
- Chapter names and main topics
- Key formulas or definitions (for math/science)
- Important concepts students must know
- Common exam questions areas

This will be used to give syllabus-accurate answers 
to students. Be specific to {board}, not generic.
Do not add explanations, just list topics."""

        response = await asyncio.to_thread(
            client.models.generate_content,
            model='gemini-2.5-flash-lite',
            contents=prompt
        )
        
        context = response.text.strip()
        _syllabus_cache[cache_key] = context
        return context
    except Exception as e:
        print(f"Error fetching dynamic syllabus: {e}")
        return _get_static_context(grade, normalized_subject)

def _get_static_context(grade: int, subject: str) -> str:
    # Keep static context as fallback
    static_data = {
        5: {
            "mathematics": "Fractions, decimals, geometry basics, percentages, ratio, and proportion.",
            "science": "Photosynthesis, food chain, digestive system, solar system, states of matter.",
            "social studies": "Karnataka geography, Indian history basics, government structure.",
        },
        6: {
            "mathematics": "Algebra introduction, ratio, proportion, area, perimeter, and volume.",
            "science": "Components of food, sorting materials, separation of substances, electricity.",
            "social studies": "Early states, kingdoms, republics, maps, diversity, government.",
        },
        7: {
            "mathematics": "Integers, triangles, congruence, rational numbers, area, perimeter.",
            "science": "Nutrition in plants/animals, heat, acids, bases, weather, climate.",
            "social studies": "Medieval history, environment, air, water, state government.",
        }
    }
    
    normalized = _normalize_subject(subject)
    grade_map = static_data.get(grade, {})
    return grade_map.get(normalized, f"{subject} curriculum for Class {grade}")

def get_grade_band(grade: int) -> str:
    if grade <= 2: return "Foundational"
    if grade <= 5: return "Primary"
    if grade <= 8: return "Middle"
    return "Secondary"
