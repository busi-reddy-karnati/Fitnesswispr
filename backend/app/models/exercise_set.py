import uuid

from sqlalchemy import INTEGER, NUMERIC, SMALLINT, VARCHAR, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ExerciseSet(Base):
    __tablename__ = "exercise_sets"

    set_id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    exercise_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("exercises.exercise_id", ondelete="CASCADE"),
        nullable=False,
    )
    set_number: Mapped[int] = mapped_column(SMALLINT, nullable=False)
    reps: Mapped[int | None] = mapped_column(SMALLINT, nullable=True)
    weight: Mapped[float | None] = mapped_column(NUMERIC(6, 2), nullable=True)
    weight_unit: Mapped[str] = mapped_column(VARCHAR(3), default="lbs", nullable=False)
    duration_seconds: Mapped[int | None] = mapped_column(INTEGER, nullable=True)

    exercise: Mapped["Exercise"] = relationship(  # noqa: F821
        "Exercise", back_populates="sets"
    )
