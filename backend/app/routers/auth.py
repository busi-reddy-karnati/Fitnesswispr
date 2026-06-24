import uuid
from datetime import datetime, timedelta, timezone
from typing import Annotated

import jwt
from fastapi import APIRouter, Depends, Header, HTTPException, Response
from sqlalchemy import delete, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.dependencies import get_db
from app.models.device_context import DeviceContext
from app.models.exercise import Exercise
from app.models.exercise_set import ExerciseSet
from app.models.health_day import HealthDay
from app.models.profile import Profile
from app.models.profile_grant import ProfileGrant
from app.models.session import WorkoutSession
from app.models.user import User
from app.schemas.requests import AppleAuthRequest
from app.schemas.responses import AuthResponse
from app.services.apple_auth import verify_identity_token

router = APIRouter()


async def get_current_user(
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str | None, Header()] = None,
) -> User:
    """Resolve the account from the `Authorization: Bearer <token>` header.

    The token is the session JWT we issue at sign-in. Raises 401 when it is
    missing, malformed, expired, or refers to an account that no longer exists.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Authentication required")
    token = authorization.split(" ", 1)[1].strip()
    try:
        payload = jwt.decode(
            token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM]
        )
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    result = await db.execute(select(User).where(User.user_id == payload.get("sub")))
    user = result.scalars().first()
    if user is None:
        raise HTTPException(status_code=401, detail="Account no longer exists")
    return user


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


@router.delete("/auth/account", status_code=204)
async def delete_account(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    """Permanently delete the signed-in account and all of its data.

    Removes the account record along with every row stored under its canonical
    UUID: workouts (and their exercises/sets), Apple Health days, the profile,
    device context, and any spotter grants the account owns or was given. This
    is irreversible and satisfies the App Store account-deletion requirement.
    """
    primary = user.primary_uuid

    # Workout sets and exercises hang off sessions. Delete them explicitly
    # (deepest first) so the data is removed regardless of whether the database
    # enforces ON DELETE CASCADE for the FK chain.
    session_ids = select(WorkoutSession.session_id).where(
        WorkoutSession.device_uuid == primary
    )
    exercise_ids = select(Exercise.exercise_id).where(
        Exercise.session_id.in_(session_ids)
    )
    await db.execute(
        delete(ExerciseSet).where(ExerciseSet.exercise_id.in_(exercise_ids))
    )
    await db.execute(delete(Exercise).where(Exercise.session_id.in_(session_ids)))
    await db.execute(
        delete(WorkoutSession).where(WorkoutSession.device_uuid == primary)
    )

    await db.execute(delete(HealthDay).where(HealthDay.device_uuid == primary))
    await db.execute(delete(Profile).where(Profile.device_uuid == primary))
    await db.execute(
        delete(DeviceContext).where(DeviceContext.device_uuid == primary)
    )
    await db.execute(
        delete(ProfileGrant).where(
            or_(
                ProfileGrant.owner_uuid == primary,
                ProfileGrant.grantee_uuid == primary,
            )
        )
    )

    await db.execute(delete(User).where(User.user_id == user.user_id))
    await db.flush()
    return Response(status_code=204)
