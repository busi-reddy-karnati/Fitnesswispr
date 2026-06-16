import uuid
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db
from app.models.health_day import HealthDay
from app.schemas.requests import HealthSyncRequest
from app.schemas.responses import HealthWorkoutResponse

router = APIRouter()


@router.post("/health/sync", status_code=204)
async def sync_health(
    body: HealthSyncRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Replace a device's Apple Health workout days with the supplied set.

    The client sends its full recent window each sync, so a full replace keeps
    the server in step with Apple Health (handles deletions too).
    """
    try:
        device_uuid = str(uuid.UUID(body.device_uuid))
    except ValueError:
        raise HTTPException(status_code=422, detail="invalid device_uuid")

    await db.execute(delete(HealthDay).where(HealthDay.device_uuid == device_uuid))
    for w in body.workouts:
        db.add(
            HealthDay(
                device_uuid=device_uuid,
                workout_date=w.workout_date,
                category=w.category,
                symbol=w.symbol,
                duration_minutes=w.duration_minutes,
            )
        )
    await db.flush()


@router.get("/health/days", response_model=list[HealthWorkoutResponse])
async def list_health(
    device_uuid: Annotated[uuid.UUID, Query(...)],
    start_date: Annotated[date | None, Query()] = None,
    end_date: Annotated[date | None, Query()] = None,
    db: AsyncSession = Depends(get_db),
) -> list[HealthDay]:
    stmt = select(HealthDay).where(HealthDay.device_uuid == str(device_uuid))
    if start_date:
        stmt = stmt.where(HealthDay.workout_date >= start_date)
    if end_date:
        stmt = stmt.where(HealthDay.workout_date <= end_date)
    result = await db.execute(stmt)
    return list(result.scalars().all())
