import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_db
from app.models.exercise import Exercise
from app.models.session import WorkoutSession
from app.services import export_service

router = APIRouter()


@router.get("/export")
async def export_workouts(
    device_uuid: Annotated[uuid.UUID, Query(...)],
    format: Annotated[str, Query(pattern="^(csv|xlsx)$")] = "csv",
    db: Annotated[AsyncSession, Depends(get_db)] = None,
) -> Response:
    """Export all workouts for a device as CSV or XLSX."""
    stmt = (
        select(WorkoutSession)
        .where(WorkoutSession.device_uuid == str(device_uuid))
        .options(selectinload(WorkoutSession.exercises).selectinload(Exercise.sets))
        .order_by(WorkoutSession.workout_date.desc())
    )
    result = await db.execute(stmt)
    sessions = list(result.scalars().all())

    if format == "xlsx":
        data = export_service.export_xlsx(sessions)
        media_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        filename = f"workouts_{device_uuid}.xlsx"
    else:
        data = export_service.export_csv(sessions)
        media_type = "text/csv"
        filename = f"workouts_{device_uuid}.csv"

    return Response(
        content=data,
        media_type=media_type,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
