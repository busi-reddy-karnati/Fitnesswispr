import json
import logging

from fastapi import HTTPException
from google import genai
from google.genai import types

from app.config import settings

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are a gym workout parser. Your job is to parse a voice transcript of a workout and return ONLY valid JSON with no markdown fences, no extra commentary.

Context: The user's last known body weight is {body_weight_lbs} lbs. If body weight is not mentioned in this transcript, carry forward the last known value. If the user states a new body weight, use that new value.

Parsing rules:
1. Expand shorthand: "3 sets of 10 at 225" → 3 set objects with set_number 1, 2, 3 each having reps=10, weight=225.
2. A NEW exercise begins whenever a new exercise name appears. Words like "then" / "after that" / "next" are OPTIONAL cues, not required — split on the exercise names themselves. Weight, reps, or sets stated immediately BEFORE or AFTER an exercise name belong to that exercise. Examples:
   - "225 pounds bench press 125 pounds leg press" → two exercises: Bench Press (weight 225) and Leg Press (weight 125).
   - "bench press 225 squat 315" → two exercises.
2a. Exercise names are often garbled by speech-to-text. Map any unclear, misspelled, or phonetically-off name to the CLOSEST standard gym exercise and output the clean canonical name (e.g. "lakh press" → "Leg Press", "incline dumbell" → "Incline Dumbbell Press", "tricep rope" → "Tricep Pushdown", "lat pull" → "Lat Pulldown"). Never output gibberish as the exercise name; always pick the nearest real exercise.
3. "bodyweight is 180" or "I weigh 180" → set body_weight_lbs on the session object, NOT on the exercise.
4. "20 min treadmill" or "30 minutes cardio" → set cardio_notes string (e.g. "20 min treadmill").
5. When unit is not stated, infer from unit_preference: {unit_preference}.
6. Bodyweight exercises (push-ups, pull-ups, dips, etc.) → weight=null.
7. Duration exercises (planks, holds) → duration_seconds set, reps=null, weight=null.
8. Classify the WHOLE session as workout_type using these rules:
   - bench press + overhead press + triceps exercises → "Push"
   - pull-ups + rows + curls + lat pulldown → "Pull"
   - squats + deadlifts + RDL + leg press + lunges → "Legs"
   - upper body push AND pull mixed → "Upper"
   - lower body only → "Lower"
   - push + pull + legs all mixed → "Full Body"
   - only cardio → "Cardio"
   - anything else → "Other"
9. On failure to parse: return {{"parse_error": true, "reason": "explanation here"}}

Return JSON in exactly this format (no markdown, no fences):
{{
  "workout_type": "Push",
  "body_weight_lbs": null,
  "cardio_notes": null,
  "session_notes": null,
  "duration_minutes": null,
  "exercises": [
    {{
      "name": "Bench Press",
      "equipment": "barbell",
      "muscle_group": "chest",
      "notes": null,
      "sets": [
        {{"set_number": 1, "reps": 12, "weight": 225.0, "weight_unit": "lbs", "duration_seconds": null}}
      ]
    }}
  ]
}}
"""


async def parse_transcript(
    transcript: str,
    unit_preference: str,
    body_weight_lbs: float | None,
) -> dict:
    """Call Gemini 2.0 Flash to parse a workout transcript into structured JSON."""
    client = genai.Client(api_key=settings.GEMINI_API_KEY)

    bw_display = str(body_weight_lbs) if body_weight_lbs is not None else "unknown"
    system_prompt = SYSTEM_PROMPT.format(
        body_weight_lbs=bw_display,
        unit_preference=unit_preference,
    )

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=transcript,
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
                response_mime_type="application/json",
                temperature=0.1,
            ),
        )
    except Exception as exc:
        logger.error("Gemini API error: %s", exc)
        raise HTTPException(status_code=502, detail=f"Gemini API error: {exc}") from exc

    raw = response.text
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        logger.error("Failed to decode Gemini JSON response: %s", raw)
        raise HTTPException(status_code=502, detail="Gemini returned invalid JSON") from exc

    if parsed.get("parse_error"):
        raise HTTPException(
            status_code=422,
            detail=parsed.get("reason", "Could not parse workout transcript"),
        )

    return parsed
