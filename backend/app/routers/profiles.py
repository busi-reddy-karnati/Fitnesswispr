import uuid
from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db
from app.models.profile import Profile
from app.models.profile_grant import ProfileGrant
from app.schemas.requests import GrantCreateRequest, ProfileUpdateRequest
from app.schemas.responses import GrantResponse, ProfileResponse, SpottingResponse

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


@router.post("/profile/{owner_uuid}/grants", response_model=GrantResponse, status_code=201)
async def create_grant(
    owner_uuid: uuid.UUID,
    body: GrantCreateRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> GrantResponse:
    """Register (or update) a spotter grant. Called by the grantee when they
    redeem an invite that the owner shared."""
    owner = str(owner_uuid)
    try:
        grantee = str(uuid.UUID(str(body.grantee_uuid)))
    except ValueError:
        raise HTTPException(status_code=422, detail="invalid grantee_uuid")
    if grantee == owner:
        raise HTTPException(status_code=422, detail="cannot grant access to yourself")
    access = body.access if body.access in ("read", "write") else "read"

    result = await db.execute(
        select(ProfileGrant).where(
            ProfileGrant.owner_uuid == owner,
            ProfileGrant.grantee_uuid == grantee,
        )
    )
    grant = result.scalars().first()
    if grant is None:
        grant = ProfileGrant(
            owner_uuid=owner,
            grantee_uuid=grantee,
            access=access,
            grantee_name=body.grantee_name,
        )
        db.add(grant)
    else:
        grant.access = access
        if body.grantee_name is not None:
            grant.grantee_name = body.grantee_name
    await db.flush()
    return GrantResponse(
        owner_uuid=owner,
        grantee_uuid=grantee,
        access=grant.access,
        grantee_name=grant.grantee_name,
    )


@router.get("/profile/{owner_uuid}/grants", response_model=list[GrantResponse])
async def list_grants(
    owner_uuid: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[GrantResponse]:
    """List the spotters who currently have access to this profile (owner view)."""
    owner = str(owner_uuid)
    result = await db.execute(
        select(ProfileGrant)
        .where(ProfileGrant.owner_uuid == owner)
        .order_by(ProfileGrant.created_at.desc())
    )
    return [
        GrantResponse(
            owner_uuid=g.owner_uuid,
            grantee_uuid=g.grantee_uuid,
            access=g.access,
            grantee_name=g.grantee_name,
        )
        for g in result.scalars().all()
    ]


@router.delete("/profile/{owner_uuid}/grants/{grantee_uuid}", status_code=204)
async def revoke_grant(
    owner_uuid: uuid.UUID,
    grantee_uuid: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    """Revoke a spotter's access (owner) or stop spotting someone (grantee)."""
    result = await db.execute(
        select(ProfileGrant).where(
            ProfileGrant.owner_uuid == str(owner_uuid),
            ProfileGrant.grantee_uuid == str(grantee_uuid),
        )
    )
    grant = result.scalars().first()
    if grant is not None:
        await db.delete(grant)
        await db.flush()
    return Response(status_code=204)


@router.get("/profile/{grantee_uuid}/spotting", response_model=list[SpottingResponse])
async def list_spotting(
    grantee_uuid: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[SpottingResponse]:
    """List the profiles this user is currently spotting (grantee view). Used to
    drop access that an owner has revoked."""
    grantee = str(grantee_uuid)
    result = await db.execute(
        select(ProfileGrant, Profile.display_name)
        .outerjoin(Profile, Profile.device_uuid == ProfileGrant.owner_uuid)
        .where(ProfileGrant.grantee_uuid == grantee)
    )
    return [
        SpottingResponse(
            owner_uuid=g.owner_uuid,
            owner_name=name,
            access=g.access,
        )
        for g, name in result.all()
    ]


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
