import uuid
from datetime import date

from sqlalchemy import String, Date, Integer, Index
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class HealthDay(Base):
    """An Apple Health workout day pushed from a person's device, so anyone who
    spots them can see their Apple Fitness consistency. Keyed by device UUID.
    """

    __tablename__ = "health_days"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    device_uuid: Mapped[str] = mapped_column(String(36), nullable=False)
    workout_date: Mapped[date] = mapped_column(Date, nullable=False)
    category: Mapped[str] = mapped_column(String(40), nullable=False)
    symbol: Mapped[str] = mapped_column(String(60), nullable=False)
    duration_minutes: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    __table_args__ = (
        Index("ix_health_days_device_uuid", "device_uuid"),
    )
