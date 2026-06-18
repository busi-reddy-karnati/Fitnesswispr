from datetime import datetime

from sqlalchemy import String, LargeBinary, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Profile(Base):
    """Per-identity profile data that needs to be shared across devices, e.g. a
    profile photo a spotter should see. Keyed by the canonical device UUID.
    """

    __tablename__ = "profiles"

    device_uuid: Mapped[str] = mapped_column(String(36), primary_key=True)
    display_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    avatar: Mapped[bytes | None] = mapped_column(LargeBinary, nullable=True)
    avatar_updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
