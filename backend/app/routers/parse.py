import logging

from fastapi import APIRouter, Depends

from app.ratelimit import enforce_llm_budget
from app.schemas.requests import ParseRequest
from app.schemas.responses import ParseResponse
from app.services import gemini_service

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post(
    "/parse",
    response_model=ParseResponse,
    dependencies=[Depends(enforce_llm_budget)],
)
async def parse_workout(request: ParseRequest) -> ParseResponse:
    """
    Parse a voice transcript using Gemini without saving to DB.
    Returns a WorkoutSessionSchema-shaped response with session_id=null.
    Exercises missing a non-empty ``name`` are silently dropped and logged
    at WARNING level; they are never forwarded to the caller.
    """
    body_weight_lbs: float | None = request.context.get("body_weight_lbs")
    # The client passes its LOCAL today (YYYY-MM-DD) so relative dates like
    # "yesterday" resolve in the user's timezone, not the server's.
    today: str | None = request.context.get("today")

    parsed = await gemini_service.parse_transcript(
        transcript=request.transcript,
        unit_preference=request.unit_preference,
        body_weight_lbs=body_weight_lbs,
        today=today,
    )

    # Normalise exercises: rename "sets" key inside each exercise if needed,
    # and skip any malformed entries that are missing a non-empty name.
    exercises = parsed.get("exercises", [])
    normalised_exercises = []
    for idx, ex in enumerate(exercises):
        name = (ex.get("name") or "").strip()
        if not name:
            logger.warning(
                "Skipping malformed exercise at index %d: missing 'name' field. Entry: %s",
                idx,
                ex,
            )
            continue
        ex_copy = dict(ex)
        ex_copy.setdefault("exercise_order", idx)
        normalised_exercises.append(ex_copy)

    return ParseResponse(
        session_id=None,
        workout_date=parsed.get("workout_date"),
        workout_type=parsed.get("workout_type"),
        body_weight_lbs=parsed.get("body_weight_lbs"),
        cardio_notes=parsed.get("cardio_notes"),
        cardio_activity=parsed.get("cardio_activity"),
        cardio_distance=parsed.get("cardio_distance"),
        cardio_distance_unit=parsed.get("cardio_distance_unit"),
        session_notes=parsed.get("session_notes"),
        duration_minutes=parsed.get("duration_minutes"),
        exercises=normalised_exercises,
    )
