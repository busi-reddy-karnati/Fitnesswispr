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
