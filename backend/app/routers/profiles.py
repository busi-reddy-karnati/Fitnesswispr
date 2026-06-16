import uuid
from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db
from app.models.profile import Profile
from app.schemas.requests import ProfileUpdateRequest
from app.schemas.responses import ProfileResponse

router = APIRouter()

# Reject oversized uploads; avatars are downscaled on the device first.
MAX_AVATAR_BYTES = 3 * 1024 * 1024  # 3 MB


async def _get_or_create(db: AsyncSession, key: str) -> Profile:
    result = await db.execute(select(Profile).where(Profile.device_uuid == key))
    profile = result.scalars().first()
    if profile is None:
        profile = Profile(device_uuid=key)
        db.add(profile)
    return profile


@router.get("/profile/{device_uuid}", response_model=ProfileResponse)
async def get_profile(
    device_uuid: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ProfileResponse:
    """Return shared profile info (current display name, whether a photo exists)."""
    key = str(device_uuid)
    result = await db.execute(select(Profile).where(Profile.device_uuid == key))
    profile = result.scalars().first()
    if profile is None:
        return ProfileResponse(device_uuid=key, name=None, has_avatar=False)
    return ProfileResponse(
        device_uuid=key,
        name=profile.display_name,
        has_avatar=profile.avatar is not None,
    )


@router.put("/profile/{device_uuid}", response_model=ProfileResponse)
async def update_profile(
    device_uuid: uuid.UUID,
    body: ProfileUpdateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ProfileResponse:
    """Upsert shared profile info (currently the display name)."""
    key = str(device_uuid)
    profile = await _get_or_create(db, key)
    if body.name is not None:
        profile.display_name = body.name
    await db.flush()
    return ProfileResponse(
        device_uuid=key,
        name=profile.display_name,
        has_avatar=profile.avatar is not None,
    )


@router.put("/profile/{device_uuid}/avatar", status_code=204)
async def upload_avatar(
    device_uuid: uuid.UUID,
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    """Store a profile photo so spotters can see it. Body is raw image bytes."""
    data = await request.body()
    if not data:
        raise HTTPException(status_code=422, detail="Empty image body")
    if len(data) > MAX_AVATAR_BYTES:
        raise HTTPException(status_code=413, detail="Image too large")

    key = str(device_uuid)
    result = await db.execute(select(Profile).where(Profile.device_uuid == key))
    profile = result.scalars().first()
    now = datetime.now(timezone.utc)
    if profile is None:
        profile = Profile(device_uuid=key, avatar=data, avatar_updated_at=now)
        db.add(profile)
    else:
        profile.avatar = data
        profile.avatar_updated_at = now
    await db.flush()
    return Response(status_code=204)


@router.get("/profile/{device_uuid}/avatar")
async def get_avatar(
    device_uuid: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    """Return the stored profile photo (JPEG), or 404 if none."""
    result = await db.execute(
        select(Profile).where(Profile.device_uuid == str(device_uuid))
    )
    profile = result.scalars().first()
    if profile is None or profile.avatar is None:
        raise HTTPException(status_code=404, detail="No avatar")
    return Response(content=profile.avatar, media_type="image/jpeg")
