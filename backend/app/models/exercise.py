import uuid

from sqlalchemy import SMALLINT, TEXT, VARCHAR, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Exercise(Base):
    __tablename__ = "exercises"

    exercise_id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    session_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("workout_sessions.session_id", ondelete="CASCADE"),
        nullable=False,
    )
    exercise_order: Mapped[int] = mapped_column(SMALLINT, nullable=False, default=0)
    name: Mapped[str] = mapped_column(VARCHAR(200), nullable=False)
    equipment: Mapped[str | None] = mapped_column(VARCHAR(100), nullable=True)
    muscle_group: Mapped[str | None] = mapped_column(VARCHAR(100), nullable=True)
    notes: Mapped[str | None] = mapped_column(TEXT, nullable=True)

    session: Mapped["WorkoutSession"] = relationship(  # noqa: F821
        "WorkoutSession", back_populates="exercises"
    )
    sets: Mapped[list["ExerciseSet"]] = relationship(  # noqa: F821
        "ExerciseSet",
        back_populates="exercise",
        cascade="all, delete-orphan",
        order_by="ExerciseSet.set_number",
    )
