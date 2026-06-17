import uuid
from datetime import date
from decimal import Decimal

from pydantic import BaseModel, Field

from app.config import settings


class ExerciseSetCreate(BaseModel):
    set_number: int
    reps: int | None = None
    weight: Decimal | None = None
    weight_unit: str = "lbs"
    duration_seconds: int | None = None


class ExerciseCreate(BaseModel):
    exercise_order: int = 0
    name: str
    equipment: str | None = None
    muscle_group: str | None = None
    notes: str | None = None
    sets: list[ExerciseSetCreate] = Field(
        default_factory=list, max_length=settings.MAX_SETS_PER_EXERCISE
    )


class ParseRequest(BaseModel):
    transcript: str = Field(max_length=settings.MAX_TRANSCRIPT_CHARS)
    device_uuid: str
    unit_preference: str = "lbs"
    context: dict = Field(default_factory=dict)


class CreateSessionRequest(BaseModel):
    device_uuid: uuid.UUID | None = None
    workout_date: date
    source: str = "voice"
    raw_transcript: str | None = None
    body_weight_lbs: Decimal | None = None
    workout_type: str | None = None
    cardio_notes: str | None = None
    session_notes: str | None = None
    duration_minutes: int | None = None
    exercises: list[ExerciseCreate] = Field(
        default_factory=list, max_length=settings.MAX_EXERCISES_PER_SESSION
    )


class UpdateSessionRequest(BaseModel):
    workout_date: date | None = None
    source: str | None = None
    raw_transcript: str | None = None
    body_weight_lbs: Decimal | None = None
    workout_type: str | None = None
    cardio_notes: str | None = None
    session_notes: str | None = None
    duration_minutes: int | None = None
    exercises: list[ExerciseCreate] | None = Field(
        default=None, max_length=settings.MAX_EXERCISES_PER_SESSION
    )
