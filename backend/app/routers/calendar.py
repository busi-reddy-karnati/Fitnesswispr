import uuid
from collections import Counter
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy import extract, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db
from app.models.session import WorkoutSession
from app.schemas.responses import CalendarEntry, CalendarResponse

router = APIRouter()


@router.get("/calendar", response_model=CalendarResponse)
async def get_calendar(
    device_uuid: Annotated[uuid.UUID, Query(...)],
    year: Annotated[int, Query(ge=2000, le=2100)],
    month: Annotated[int, Query(ge=1, le=12)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> CalendarResponse:
    """Return workout dates and types for a given month."""
    stmt = (
        select(WorkoutSession.workout_date, WorkoutSession.workout_type)
        .where(WorkoutSession.device_uuid == str(device_uuid))
        .where(extract("year", WorkoutSession.workout_date) == year)
        .where(extract("month", WorkoutSession.workout_date) == month)
        .order_by(WorkoutSession.workout_date)
    )
    result = await db.execute(stmt)
    rows = result.all()

    # A day may have multiple sessions, but the calendar shows one dot per day.
    # The day's type is the MAJORITY workout_type among that day's sessions
    # (ties resolve to the earliest-logged type; days with only untyped
    # sessions stay None). Rows are ordered by date, preserving day order.
    types_by_date: dict[object, list] = {}
    for row in rows:
        types_by_date.setdefault(row.workout_date, []).append(row.workout_type)

    entries = []
    for day, types in types_by_date.items():
        typed = [t for t in types if t is not None]
        majority = Counter(typed).most_common(1)[0][0] if typed else None
        entries.append(CalendarEntry(date=day, workout_type=majority))

    return CalendarResponse(dates=entries)
