from datetime import datetime

from sqlalchemy import String, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class ProfileGrant(Base):
    """A "spotter" access grant: `owner_uuid` lets `grantee_uuid` view (and
    optionally log) their training. The grantee registers the grant when they
    redeem an invite; the owner can revoke it. Used so an owner can see who has
    access and so a spotter's app can drop access that was revoked.
    """

    __tablename__ = "profile_grants"

    owner_uuid: Mapped[str] = mapped_column(String(36), primary_key=True)
    grantee_uuid: Mapped[str] = mapped_column(String(36), primary_key=True)
    access: Mapped[str] = mapped_column(String(10), default="read", nullable=False)
    grantee_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
