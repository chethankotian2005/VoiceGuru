from __future__ import annotations

import asyncio
import os
from datetime import datetime, timedelta, timezone
from threading import Lock
from typing import Any

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except Exception:  # pragma: no cover - handled safely at runtime
    firebase_admin = None
    credentials = None
    firestore = None


_firebase_lock = Lock()
_firebase_app = None
_firestore_client = None


def _empty_history() -> list:
    return []


def _empty_summary() -> dict:
    return {
        "total_questions": 0,
        "subjects_asked": [],
        "most_asked_subject": "",
        "questions": [],
    }


def _serialize_value(value: Any) -> Any:
    if hasattr(value, "isoformat"):
        try:
            return value.isoformat()
        except Exception:
            return value
    return value


def _credentials_path() -> str:
    env_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "").strip()
    return env_path


def _initialize_firebase_app() -> Any:
    global _firebase_app

    if firebase_admin is None or credentials is None or firestore is None:
        return None

    credentials_path = _credentials_path()
    if not credentials_path or not os.path.exists(credentials_path):
        return None

    with _firebase_lock:
        try:
            if _firebase_app is not None:
                return _firebase_app
            _firebase_app = firebase_admin.get_app()
            return _firebase_app
        except Exception:
            try:
                cred = credentials.Certificate(credentials_path)
                _firebase_app = firebase_admin.initialize_app(cred)
                return _firebase_app
            except Exception:
                return None


def _get_firestore_client() -> Any:
    global _firestore_client

    if _firestore_client is not None:
        return _firestore_client

    app = _initialize_firebase_app()
    if app is None or firestore is None:
        return None

    try:
        _firestore_client = firestore.client(app=app)
        return _firestore_client
    except Exception:
        try:
            _firestore_client = firestore.client()
            return _firestore_client
        except Exception:
            return None


def _collection():
    client = _get_firestore_client()
    if client is None:
        return None
    return client.collection("questions")


async def log_question(
    child_id: str,
    question: str,
    explanation: str,
    subject: str,
    grade: int,
    language: str,
):
    try:
        collection = _collection()
        if collection is None:
            return None

        payload = {
            "child_id": child_id,
            "question": question,
            "explanation": explanation,
            "subject": subject,
            "grade": grade,
            "language": language,
            "timestamp": firestore.SERVER_TIMESTAMP,
        }
        await asyncio.to_thread(collection.add, payload)
        return None
    except Exception:
        return None


async def get_child_history(child_id: str) -> list:
    try:
        collection = _collection()
        if collection is None:
            return _empty_history()

        def _query() -> list:
            docs = (
                collection.where("child_id", "==", child_id)
                .order_by("timestamp", direction=firestore.Query.DESCENDING)
                .limit(20)
                .stream()
            )
            results: list[dict[str, Any]] = []
            for doc in docs:
                data = doc.to_dict() or {}
                data = {key: _serialize_value(value) for key, value in data.items()}
                results.append(data)
            return results

        return await asyncio.to_thread(_query)
    except Exception:
        return _empty_history()


async def get_weekly_summary(child_id: str) -> dict:
    try:
        collection = _collection()
        if collection is None:
            return _empty_summary()

        cutoff = datetime.now(timezone.utc) - timedelta(days=7)

        def _query() -> dict:
            docs = (
                collection.where("child_id", "==", child_id)
                .where("timestamp", ">=", cutoff)
                .order_by("timestamp", direction=firestore.Query.DESCENDING)
                .stream()
            )

            questions: list[str] = []
            subjects_count: dict[str, int] = {}
            total_questions = 0

            for doc in docs:
                data = doc.to_dict() or {}
                question_text = data.get("question", "")
                subject = data.get("subject", "")

                if question_text:
                    questions.append(question_text)
                if subject:
                    subjects_count[subject] = subjects_count.get(subject, 0) + 1
                total_questions += 1

            most_asked_subject = ""
            if subjects_count:
                most_asked_subject = max(subjects_count.items(), key=lambda item: item[1])[0]

            return {
                "total_questions": total_questions,
                "subjects_asked": list(subjects_count.keys()),
                "most_asked_subject": most_asked_subject,
                "questions": questions,
            }

        return await asyncio.to_thread(_query)
    except Exception:
        return _empty_summary()


async def get_progress_data(child_id: str) -> dict:
    try:
        collection = _collection()
        if collection is None:
            raise ValueError("Firebase not connected")

        def _query() -> dict:
            # We fetch all questions for this child to build complete history
            # For massive datasets, this should be optimized or cached
            docs = collection.where("child_id", "==", child_id).order_by("timestamp", direction=firestore.Query.DESCENDING).stream()
            
            total_questions = 0
            today_questions = 0
            subjects = {"math": 0, "science": 0, "social_studies": 0, "other": 0}
            
            now = datetime.now(timezone.utc)
            today_date = now.date()
            
            daily_counts = {}
            
            for doc in docs:
                data = doc.to_dict() or {}
                total_questions += 1
                
                # Timestamp handling
                ts = data.get("timestamp")
                if not ts:
                    continue
                if hasattr(ts, "timestamp"):
                    dt = datetime.fromtimestamp(ts.timestamp(), tz=timezone.utc)
                else:
                    dt = ts # if it's already a datetime
                    
                date_obj = dt.date()
                date_str = date_obj.isoformat()
                daily_counts[date_str] = daily_counts.get(date_str, 0) + 1
                
                if date_obj == today_date:
                    today_questions += 1
                    
                # Subject handling
                subj = str(data.get("subject", "other")).lower()
                if "math" in subj: subjects["math"] += 1
                elif "science" in subj: subjects["science"] += 1
                elif "social" in subj: subjects["social_studies"] += 1
                else: subjects["other"] += 1

            # Streak calculation
            streak_days = 0
            check_date = today_date
            if check_date.isoformat() not in daily_counts:
                # If they haven't asked today, check if they asked yesterday (active streak)
                check_date = check_date - timedelta(days=1)
                
            while check_date.isoformat() in daily_counts:
                streak_days += 1
                check_date = check_date - timedelta(days=1)

            # Weekly data (Last 7 days)
            weekly_data = []
            for i in range(6, -1, -1):
                d = today_date - timedelta(days=i)
                d_str = d.isoformat()
                day_name = d.strftime("%a")
                weekly_data.append({
                    "day": day_name,
                    "questions": daily_counts.get(d_str, 0),
                    "date": d_str
                })

            # Monthly data (Last 4 weeks)
            monthly_data = []
            for i in range(4):
                week_start = today_date - timedelta(days=(3 - i) * 7 + today_date.weekday())
                week_questions = sum(
                    daily_counts.get((week_start + timedelta(days=j)).isoformat(), 0)
                    for j in range(7)
                )
                monthly_data.append({
                    "week": f"Week {i+1}",
                    "questions": week_questions
                })

            # Badges logic
            badges = []
            if total_questions >= 1: badges.append("first_question")
            if total_questions >= 10: badges.append("10_questions")
            if streak_days >= 3: badges.append("3_day_streak")
            if subjects["science"] >= 5: badges.append("science_explorer")
            if subjects["math"] >= 5: badges.append("math_wizard")
            if subjects["social_studies"] >= 5: badges.append("geography_expert")
            
            # Speed learner badge: 5 in one day
            if any(count >= 5 for count in daily_counts.values()):
                badges.append("speed_learner")

            return {
                "streak_days": streak_days,
                "total_questions": total_questions,
                "today_questions": today_questions,
                "daily_goal": 5,
                "weekly_data": weekly_data,
                "monthly_data": monthly_data,
                "subject_breakdown": subjects,
                "badges": badges
            }

        return await asyncio.to_thread(_query)
    except Exception as e:
        import traceback
        traceback.print_exc()
        # Safe empty fallback
        now = datetime.now(timezone.utc).date()
        return {
            "streak_days": 0, "total_questions": 0, "today_questions": 0, "daily_goal": 5,
            "weekly_data": [{"day": (now - timedelta(days=i)).strftime("%a"), "questions": 0, "date": (now - timedelta(days=i)).isoformat()} for i in range(6, -1, -1)],
            "monthly_data": [{"week": f"Week {i+1}", "questions": 0} for i in range(4)],
            "subject_breakdown": {"math": 0, "science": 0, "social_studies": 0, "other": 0},
            "badges": []
        }

async def get_today_topics(child_id: str) -> list[str]:
    try:
        collection = _collection()
        if collection is None:
            return []

        now = datetime.now(timezone.utc)
        start_of_day = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)

        def _query() -> list[str]:
            docs = (
                collection.where("child_id", "==", child_id)
                .where("timestamp", ">=", start_of_day)
                .stream()
            )
            topics = set()
            for doc in docs:
                data = doc.to_dict() or {}
                # In VoiceGuru, topic isn't explicitly saved, but we can use question/explanation keywords or subject
                subj = data.get("subject", "")
                if subj and subj.lower() != "general":
                    topics.add(subj)
                
                # Optionally add key_terms if they are logged, but currently they aren't
            return list(topics)

        return await asyncio.to_thread(_query)
    except Exception:
        return []

async def save_quiz_result(child_id: str, score: int, total: int, grade: int, language: str) -> None:
    try:
        client = _get_firestore_client()
        if client is None:
            return None

        collection = client.collection("quiz_results")

        payload = {
            "child_id": child_id,
            "score": score,
            "total": total,
            "grade": grade,
            "language": language,
            "timestamp": firestore.SERVER_TIMESTAMP,
        }
        await asyncio.to_thread(collection.add, payload)
    except Exception:
        pass

async def save_user_profile(child_id: str, name: str, grade: int, board: str, language: str, mascot: str) -> None:
    try:
        client = _get_firestore_client()
        if client is None:
            return None

        collection = client.collection("users")
        doc_ref = collection.document(child_id)
        
        payload = {
            "child_id": child_id,
            "name": name,
            "grade": grade,
            "board": board,
            "language": language,
            "mascot": mascot,
            "updated_at": firestore.SERVER_TIMESTAMP,
        }
        # Use merge=True so we don't overwrite other fields if they exist
        await asyncio.to_thread(doc_ref.set, payload, merge=True)
    except Exception:
        pass

async def get_user_profile(child_id: str) -> dict | None:
    try:
        client = _get_firestore_client()
        if client is None:
            return None

        def _query():
            doc_ref = client.collection("users").document(child_id)
            doc = doc_ref.get()
            if doc.exists:
                return doc.to_dict()
            return None

        return await asyncio.to_thread(_query)
    except Exception:
        return None