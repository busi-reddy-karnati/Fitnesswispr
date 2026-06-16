import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict

from app.schemas.workout import WorkoutSessionSchema


class ParseResponse(WorkoutSessionSchema):
    session_id: uuid.UUID | None = None


class CalendarEntry(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    date: date
    workout_type: str | None = None


class CalendarResponse(BaseModel):
    dates: list[CalendarEntry]


class DeviceContextResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    device_uuid: uuid.UUID | None = None
    last_body_weight_lbs: float | None = None
    last_updated: datetime | None = None


class ProfileResponse(BaseModel):
    device_uuid: str
    name: str | None = None
    has_avatar: bool = False


class HealthWorkoutResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    workout_date: date
    category: str
    symbol: str
    duration_minutes: int


class AuthResponse(BaseModel):
    # Our own session token (JWT) the app stores and can send on requests.
    token: str
    # The canonical UUID the app should use as its identity from now on.
    primary_uuid: str
    email: str | None = None
    full_name: str | None = None
    # True when this sign-in created the account (claimed the local UUID).
    is_new: bool
