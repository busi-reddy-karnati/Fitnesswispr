from datetime import datetime

from sqlalchemy import NUMERIC, String, DateTime
from sqlalchemy import func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class DeviceContext(Base):
    __tablename__ = "device_context"

    device_uuid: Mapped[str] = mapped_column(String(36), primary_key=True)
    last_body_weight_lbs: Mapped[float | None] = mapped_column(NUMERIC(5, 1), nullable=True)
    last_updated: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
