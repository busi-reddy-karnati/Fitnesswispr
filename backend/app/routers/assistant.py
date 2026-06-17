"""Conversational assistant endpoint — answers questions grounded in the
caller's logged workout history."""
import uuid
from datetime import date, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_db
from app.models.exercise import Exercise
from app.models.session import WorkoutSession
from app.ratelimit import enforce_llm_budget
from app.config import settings
from app.services import gemini_service

router = APIRouter()

HISTORY_DAYS = 180
MAX_SESSIONS = 120


class AssistantChatRequest(BaseModel):
    device_uuid: str
    message: str = Field(max_length=settings.MAX_ASSISTANT_CHARS)


class AssistantChatResponse(BaseModel):
    reply: str


def _summarize(sessions: list[WorkoutSession]) -> str:
    """Compact, LLM-friendly rendering of recent sessions (most recent first)."""
    lines: list[str] = []
    for s in sessions:
        parts: list[str] = []
        for ex in sorted(s.exercises, key=lambda e: e.exercise_order or 0):
            sets = list(ex.sets)
            if not sets:
                parts.append(ex.name)
                continue
            weights = [st.weight for st in sets if st.weight is not None]
            reps = [st.reps for st in sets if st.reps is not None]
            seg = f"{ex.name}: {len(sets)} sets"
            if weights:
                top = max(weights)
                unit = next((st.weight_unit for st in sets if st.weight is not None), "lbs")
                seg += f", top {top:g}{unit}"
            if reps:
                seg += f", reps {'/'.join(str(r) for r in reps)}"
            holds = [st.duration_seconds for st in sets if st.duration_seconds]
            if holds:
                seg += f", hold {max(holds)}s"
            parts.append(seg)
        wtype = f"[{s.workout_type}] " if s.workout_type else ""
        lines.append(f"{s.workout_date} {wtype}" + "; ".join(parts))
    return "\n".join(lines)


@router.post(
    "/assistant/chat",
    response_model=AssistantChatResponse,
    dependencies=[Depends(enforce_llm_budget)],
)
async def assistant_chat(
    body: AssistantChatRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    x_device_uuid: Annotated[str | None, Header()] = None,
) -> AssistantChatResponse:
    raw_device = body.device_uuid or x_device_uuid
    if not raw_device:
        raise HTTPException(status_code=422, detail="device_uuid is required")
    try:
        device_uuid = str(uuid.UUID(str(raw_device)))
    except ValueError:
        raise HTTPException(status_code=422, detail="invalid device_uuid")

    if not body.message.strip():
        raise HTTPException(status_code=422, detail="message is required")

    today = date.today()
    start = today - timedelta(days=HISTORY_DAYS)
    stmt = (
        select(WorkoutSession)
        .where(WorkoutSession.device_uuid == device_uuid)
        .where(WorkoutSession.workout_date >= start)
        .options(selectinload(WorkoutSession.exercises).selectinload(Exercise.sets))
        .order_by(WorkoutSession.workout_date.desc())
        .limit(MAX_SESSIONS)
    )
    result = await db.execute(stmt)
    sessions = list(result.scalars().all())

    history = _summarize(sessions)
    reply = await gemini_service.answer_question(
        question=body.message, history=history, today=today.isoformat()
    )
    return AssistantChatResponse(reply=reply)
