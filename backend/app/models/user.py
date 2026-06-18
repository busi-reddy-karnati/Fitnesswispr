import uuid
from datetime import datetime

from sqlalchemy import String, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class User(Base):
    """An account backed by an external identity provider (Sign in with Apple).

    `primary_uuid` is the canonical device UUID that all of the account's data
    is stored under. Signing in on any device adopts this UUID so the user's
    history follows their account across devices and reinstalls.
    """

    __tablename__ = "users"

    user_id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    # Apple's stable subject identifier ("sub" claim). Unique per Apple ID.
    apple_sub: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    email: Mapped[str | None] = mapped_column(String(320), nullable=True)
    full_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    # Canonical UUID that this account's workout data lives under.
    primary_uuid: Mapped[str] = mapped_column(String(36), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
