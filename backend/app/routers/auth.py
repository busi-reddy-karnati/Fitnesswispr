import uuid
from datetime import datetime, timedelta, timezone
from typing import Annotated

import jwt
from fastapi import APIRouter, Depends
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.dependencies import get_db
from app.models.device_context import DeviceContext
from app.models.session import WorkoutSession
from app.models.user import User
from app.schemas.requests import AppleAuthRequest
from app.schemas.responses import AuthResponse
from app.services.apple_auth import verify_identity_token

router = APIRouter()


def _issue_token(user: User) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user.user_id,
        "uid": user.primary_uuid,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(days=settings.JWT_EXPIRE_DAYS)).timestamp()),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def _normalise_uuid(raw: str | None) -> str | None:
    if not raw:
        return None
    try:
        return str(uuid.UUID(str(raw)))
    except ValueError:
        return None


async def _merge_device_data(
    db: AsyncSession, from_uuid: str, to_uuid: str
) -> None:
    """Reassign a device's anonymous data to the account's canonical UUID."""
    if from_uuid == to_uuid:
        return
    await db.execute(
        update(WorkoutSession)
        .where(WorkoutSession.device_uuid == from_uuid)
        .values(device_uuid=to_uuid)
    )
    # device_context has a UUID primary key, so only move it if the target
    # doesn't already have one.
    existing = await db.execute(
        select(DeviceContext).where(DeviceContext.device_uuid == to_uuid)
    )
    if existing.scalars().first() is None:
        await db.execute(
            update(DeviceContext)
            .where(DeviceContext.device_uuid == from_uuid)
            .values(device_uuid=to_uuid)
        )


@router.post("/auth/apple", response_model=AuthResponse)
async def sign_in_with_apple(
    body: AppleAuthRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AuthResponse:
    """Verify a Sign in with Apple identity token and return the account's
    canonical UUID plus a session token. Creates the account on first sign-in.
    """
    identity = await verify_identity_token(body.identity_token)
    local_uuid = _normalise_uuid(body.device_uuid)

    result = await db.execute(select(User).where(User.apple_sub == identity.sub))
    user = result.scalars().first()

    if user is None:
        # First sign-in: claim the device's local UUID as the canonical one so
        # existing anonymous data immediately belongs to the account.
        primary = local_uuid or str(uuid.uuid4())
        user = User(
            apple_sub=identity.sub,
            email=identity.email,
            full_name=body.full_name,
            primary_uuid=primary,
        )
        db.add(user)
        await db.flush()
        is_new = True
    else:
        # Returning user signing in on a (possibly new) device: merge any local
        # anonymous data into the account's canonical UUID.
        if local_uuid:
            await _merge_device_data(db, local_uuid, user.primary_uuid)
        if body.full_name and not user.full_name:
            user.full_name = body.full_name
        if identity.email and not user.email:
            user.email = identity.email
        is_new = False

    await db.flush()
    return AuthResponse(
        token=_issue_token(user),
        primary_uuid=user.primary_uuid,
        email=user.email,
        full_name=user.full_name,
        is_new=is_new,
    )
