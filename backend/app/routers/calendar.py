import uuid
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

    entries = [
        CalendarEntry(date=row.workout_date, workout_type=row.workout_type)
        for row in rows
    ]
    return CalendarResponse(dates=entries)
