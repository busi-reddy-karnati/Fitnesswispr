import uuid
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db
from app.models.device_context import DeviceContext
from app.schemas.responses import DeviceContextResponse

router = APIRouter()


@router.get("/devices/{device_uuid}/context", response_model=DeviceContextResponse)
async def get_device_context(
    device_uuid: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> DeviceContextResponse:
    """Return the last known body weight and context for a device."""
    result = await db.execute(
        select(DeviceContext).where(DeviceContext.device_uuid == str(device_uuid))
    )
    ctx = result.scalars().first()

    if ctx is None:
        return DeviceContextResponse(
            device_uuid=device_uuid,
            last_body_weight_lbs=None,
            last_updated=None,
        )

    return DeviceContextResponse(
        device_uuid=ctx.device_uuid,
        last_body_weight_lbs=ctx.last_body_weight_lbs,
        last_updated=ctx.last_updated,
    )
