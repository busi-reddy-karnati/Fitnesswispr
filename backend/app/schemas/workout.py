import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict


class ExerciseSetSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    set_id: uuid.UUID | None = None
    set_number: int
    reps: int | None = None
    weight: float | None = None
    weight_unit: str = "lbs"
    duration_seconds: int | None = None


class ExerciseSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    exercise_id: uuid.UUID | None = None
    exercise_order: int = 0
    name: str
    equipment: str | None = None
    muscle_group: str | None = None
    notes: str | None = None
    sets: list[ExerciseSetSchema] = []


class WorkoutSessionSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    session_id: uuid.UUID | None = None
    device_uuid: uuid.UUID | None = None
    workout_date: date | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
    source: str = "voice"
    raw_transcript: str | None = None
    body_weight_lbs: float | None = None
    workout_type: str | None = None
    cardio_notes: str | None = None
    session_notes: str | None = None
    duration_minutes: int | None = None
    exercises: list[ExerciseSchema] = []
