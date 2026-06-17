import uuid
from datetime import date, datetime

from sqlalchemy import DATE, INTEGER, NUMERIC, TEXT, VARCHAR, Index, String, DateTime
from sqlalchemy import func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class WorkoutSession(Base):
    __tablename__ = "workout_sessions"

    session_id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    device_uuid: Mapped[str] = mapped_column(String(36), nullable=False)
    workout_date: Mapped[date] = mapped_column(DATE, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        onupdate=func.now(),
        nullable=True,
    )
    source: Mapped[str] = mapped_column(VARCHAR(20), default="voice", nullable=False)
    raw_transcript: Mapped[str | None] = mapped_column(TEXT, nullable=True)
    body_weight_lbs: Mapped[float | None] = mapped_column(NUMERIC(5, 1), nullable=True)
    workout_type: Mapped[str | None] = mapped_column(VARCHAR(30), nullable=True)
    cardio_notes: Mapped[str | None] = mapped_column(TEXT, nullable=True)
    cardio_activity: Mapped[str | None] = mapped_column(VARCHAR(40), nullable=True)
    cardio_distance: Mapped[float | None] = mapped_column(NUMERIC(7, 2), nullable=True)
    cardio_distance_unit: Mapped[str | None] = mapped_column(VARCHAR(8), nullable=True)
    session_notes: Mapped[str | None] = mapped_column(TEXT, nullable=True)
    duration_minutes: Mapped[int | None] = mapped_column(INTEGER, nullable=True)

    exercises: Mapped[list["Exercise"]] = relationship(  # noqa: F821
        "Exercise",
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="Exercise.exercise_order",
    )

    __table_args__ = (
        Index("ix_workout_sessions_device_uuid", "device_uuid"),
        Index("ix_workout_sessions_workout_date", "workout_date"),
    )
