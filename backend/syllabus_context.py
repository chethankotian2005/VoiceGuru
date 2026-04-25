from __future__ import annotations


SYLLABUS_CONTEXT: dict[int, dict[str, str]] = {
    5: {
        "mathematics": (
            "Karnataka State Board curriculum, Grade 5 Mathematics: common doubts include fractions, decimals, "
            "geometry basics, and early ideas of percentages, ratio, and proportion using grade-appropriate "
            "terminology such as numerator, denominator, equivalent fraction, shape, and unit. Introduce algebra "
            "through number patterns, and preview area, perimeter, and volume with simple classroom objects. Use "
            "local examples such as auto-rickshaw speed stories for time-distance, ragi sack counting for fractions, "
            "and water storage linked to Cauvery river examples."
        ),
        "science": (
            "Karnataka State Board curriculum, Grade 5 Science: common doubts cover photosynthesis, food chain, "
            "digestive system, solar system, and states of matter with simple cause-and-effect wording. Build "
            "foundation ideas for electricity basics and force and motion through safe daily observations. Use local "
            "examples like ragi plants for nutrition and agriculture, Cauvery river water for the water cycle and "
            "states of matter, and toy-cart push and pull for motion."
        ),
        "social studies": (
            "Karnataka State Board curriculum, Grade 5 Social Studies: common doubts include Karnataka geography, "
            "Indian history basics, government structure at a simple level, and Bangalore landmarks. Use "
            "grade-appropriate terminology such as district, state, map, timeline, and civic duty. Include local "
            "examples like Vidhana Soudha for civics and neighborhood routes for map understanding."
        ),
    },
    6: {
        "mathematics": (
            "Karnataka State Board curriculum, Grade 6 Mathematics: common doubts include fractions, decimals, "
            "geometry basics, algebra introduction, percentages, ratio, proportion, area, perimeter, and early "
            "volume ideas. Use grade-appropriate terminology such as variable, expression, equation, and unit rate. "
            "Use local examples like auto-rickshaw fare and speed comparisons, ragi bag weights for ratios, and "
            "Cauvery water tank measurements for area and volume reasoning."
        ),
        "science": (
            "Karnataka State Board curriculum, Grade 6 Science: common doubts include photosynthesis, food chain, "
            "digestive system, solar system, electricity basics, states of matter, and force and motion. Use "
            "grade-appropriate terminology such as producer, consumer, digestion, conductor, and friction. Use local "
            "examples like ragi crops, Cauvery river water changes, simple battery-bulb circuits, and bicycle braking "
            "for motion and force."
        ),
        "social studies": (
            "Karnataka State Board curriculum, Grade 6 Social Studies: common doubts include Karnataka geography, "
            "Indian history basics, government structure, and Bangalore landmarks. Use grade-appropriate terminology "
            "such as plateau, river basin, constitution, legislature, and heritage. Use local examples including "
            "Vidhana Soudha for civics, Cauvery basin maps for geography, and city landmarks for place-based history."
        ),
    },
    7: {
        "mathematics": (
            "Karnataka State Board curriculum, Grade 7 Mathematics: common doubts include fractions, decimals, "
            "geometry basics, algebra introduction, percentages, ratio, proportion, area, perimeter, and volume. Use "
            "grade-appropriate terminology such as linear expression, circumference, surface area, and volume units. "
            "Use local examples like auto-rickshaw speed-time questions, ragi farm plot measurements, and Cauvery "
            "water-tank volume calculations."
        ),
        "science": (
            "Karnataka State Board curriculum, Grade 7 Science: common doubts include photosynthesis, food chain, "
            "digestive system, solar system, electricity basics, states of matter, and force and motion. Use "
            "grade-appropriate terminology such as circuit, current, orbit, evaporation, and balanced force. Use local "
            "examples like ragi ecosystem links, Cauvery river water use and conservation, and household electricity "
            "safety."
        ),
        "social studies": (
            "Karnataka State Board curriculum, Grade 7 Social Studies: common doubts include Karnataka geography in "
            "detail, Indian history basics, government structure, and Bangalore landmarks. Use grade-appropriate "
            "terminology such as monsoon, administration, representation, and institution. Use local examples such as "
            "Vidhana Soudha for governance and Bangalore map routes for practical geography."
        ),
    },
    8: {
        "mathematics": (
            "Karnataka State Board curriculum, Grade 8 Mathematics: common doubts include fractions, decimals, "
            "geometry basics, algebra introduction, percentages, ratio, proportion, area, perimeter, and volume. Use "
            "grade-appropriate terminology such as equation, factor, identity, surface area, and volume. Use local "
            "examples like auto-rickshaw speed and fare models, ragi field area estimation, and Cauvery water storage "
            "problems."
        ),
        "science": (
            "Karnataka State Board curriculum, Grade 8 Science: common doubts include photosynthesis, food chain, "
            "digestive system, solar system, electricity basics, states of matter, and force and motion. Use "
            "grade-appropriate terminology such as current, resistance (intro), pressure, and acceleration. Use local "
            "examples like ragi crop science, Cauvery river water quality and flow context, and everyday appliances for "
            "electricity concepts."
        ),
        "social studies": (
            "Karnataka State Board curriculum, Grade 8 Social Studies: common doubts include Karnataka geography, "
            "Indian history basics, government structure, and Bangalore landmarks tied to civic understanding. Use "
            "grade-appropriate terminology such as democracy, executive, judiciary, rights, and institutions. Use local "
            "examples such as Vidhana Soudha for civics, Cauvery basin and district maps for geography, and Bangalore "
            "landmarks for historical connections."
        ),
    },
}


GENERIC_CONTEXT = (
    "Karnataka State Board curriculum context: explain concepts with grade-appropriate terminology, simple steps, "
    "and local examples from Karnataka such as auto-rickshaw speed comparisons, ragi agriculture, Cauvery river "
    "water references, and Vidhana Soudha for civics topics."
)


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


def get_syllabus_context(grade: int, subject: str) -> str:
    normalized_subject = _normalize_subject(subject)
    grade_map = SYLLABUS_CONTEXT.get(grade)
    if not grade_map:
        return GENERIC_CONTEXT

    return grade_map.get(normalized_subject, GENERIC_CONTEXT)


def get_grade_band(grade: int) -> str:
    if grade <= 2:
        return "Foundational"
    if grade <= 5:
        return "Primary"
    if grade <= 8:
        return "Middle"
    return "Secondary"


def build_context(subject: str, grade: int) -> str:
    context = get_syllabus_context(grade=grade, subject=subject)
    band = get_grade_band(grade)
    return f"{context} Grade band: {band}."
