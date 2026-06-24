"""Bulk exercise rename / merge across a device's logged history.

Powers two product features:
- Merging two near-identical exercises (e.g. "Lat Pulldown" vs "Lat Pulldowns")
  under one clean name picked by the LLM.
- A chat command ("rename all my Bench Pres to Bench Press") that previews every
  affected entry before applying.
"""
import uuid
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import settings
from app.dependencies import get_db
from app.models.exercise import Exercise
from app.models.session import WorkoutSession
from app.ratelimit import enforce_llm_budget
from app.services import exercise_name, gemini_service

router = APIRouter()

MAX_OCCURRENCES = 500


class RenameExerciseRequest(BaseModel):
    device_uuid: str
    from_names: list[str] = Field(min_length=1, max_length=50)
    to_name: str = Field(min_length=1, max_length=200)
    # "canonical" also catches plural/synonym variants; "exact" matches the
    # literal (case-insensitive, trimmed) name only.
    match: str = "canonical"
    dry_run: bool = False


class RenameOccurrence(BaseModel):
    session_id: str
    workout_date: date
    old_name: str
    set_count: int


class RenameExerciseResponse(BaseModel):
    to_name: str
    matched_count: int
    session_count: int
    occurrences: list[RenameOccurrence]
    applied: bool


class SuggestNameRequest(BaseModel):
    names: list[str] = Field(min_length=1, max_length=20)


class SuggestNameResponse(BaseModel):
    name: str


class ParseCommandRequest(BaseModel):
    device_uuid: str
    message: str = Field(max_length=settings.MAX_ASSISTANT_CHARS)
    known_names: list[str] = Field(default_factory=list, max_length=400)


class ParseCommandResponse(BaseModel):
    is_rename: bool
    from_names: list[str]
    to_name: str | None


def _normalize_device(raw: str) -> str:
    try:
        return str(uuid.UUID(str(raw)))
    except ValueError:
        raise HTTPException(status_code=422, detail="invalid device_uuid")


async def _device_exercises(
    device_uuid: str, db: AsyncSession
) -> list[tuple[WorkoutSession, Exercise]]:
    stmt = (
        select(WorkoutSession)
        .where(WorkoutSession.device_uuid == device_uuid)
        .options(selectinload(WorkoutSession.exercises).selectinload(Exercise.sets))
        .order_by(WorkoutSession.workout_date.desc())
    )
    result = await db.execute(stmt)
    pairs: list[tuple[WorkoutSession, Exercise]] = []
    for session in result.scalars().all():
        for ex in session.exercises:
            pairs.append((session, ex))
    return pairs


@router.post("/exercises/rename", response_model=RenameExerciseResponse)
async def rename_exercise(
    body: RenameExerciseRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> RenameExerciseResponse:
    device_uuid = _normalize_device(body.device_uuid)
    to_name = body.to_name.strip()
    if not to_name:
        raise HTTPException(status_code=422, detail="to_name is required")

    if body.match == "exact":
        targets = {n.strip().lower() for n in body.from_names if n.strip()}

        def matches(name: str) -> bool:
            return name.strip().lower() in targets
    else:
        targets = {exercise_name.canonical_key(n) for n in body.from_names if n.strip()}

        def matches(name: str) -> bool:
            return exercise_name.canonical_key(name) in targets

    if not targets:
        raise HTTPException(status_code=422, detail="from_names is required")

    pairs = await _device_exercises(device_uuid, db)
    matched = [
        (s, ex) for (s, ex) in pairs if matches(ex.name) and ex.name.strip() != to_name
    ]

    occurrences = [
        RenameOccurrence(
            session_id=s.session_id,
            workout_date=s.workout_date,
            old_name=ex.name,
            set_count=len(ex.sets),
        )
        for (s, ex) in matched[:MAX_OCCURRENCES]
    ]
    session_ids = {s.session_id for (s, _) in matched}

    applied = False
    if not body.dry_run and matched:
        for _, ex in matched:
            ex.name = to_name
        await db.flush()
        applied = True

    return RenameExerciseResponse(
        to_name=to_name,
        matched_count=len(matched),
        session_count=len(session_ids),
        occurrences=occurrences,
        applied=applied,
    )


@router.post(
    "/exercises/suggest-name",
    response_model=SuggestNameResponse,
    dependencies=[Depends(enforce_llm_budget)],
)
async def suggest_name(body: SuggestNameRequest) -> SuggestNameResponse:
    names = [n.strip() for n in body.names if n.strip()]
    if not names:
        raise HTTPException(status_code=422, detail="names is required")
    if len(names) == 1:
        return SuggestNameResponse(name=names[0])
    suggested = await gemini_service.suggest_exercise_name(names)
    return SuggestNameResponse(name=suggested)


@router.post(
    "/exercises/parse-command",
    response_model=ParseCommandResponse,
    dependencies=[Depends(enforce_llm_budget)],
)
async def parse_command(body: ParseCommandRequest) -> ParseCommandResponse:
    _normalize_device(body.device_uuid)
    if not body.message.strip():
        raise HTTPException(status_code=422, detail="message is required")
    result = await gemini_service.parse_rename_command(
        message=body.message,
        known_names=body.known_names[:400],
    )
    return ParseCommandResponse(
        is_rename=bool(result.get("is_rename")),
        from_names=[str(n) for n in (result.get("from_names") or []) if str(n).strip()],
        to_name=(result.get("to_name") or None),
    )
