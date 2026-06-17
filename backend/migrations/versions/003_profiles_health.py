"""Add profiles (shared avatar) and health_days (shared Apple Fitness)

Revision ID: 003
Revises: 002
Create Date: 2026-06-16 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "003"
down_revision: Union[str, None] = "002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "profiles",
        sa.Column("device_uuid", sa.String(36), primary_key=True),
        sa.Column("avatar", sa.LargeBinary(), nullable=True),
        sa.Column("avatar_updated_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )

    op.create_table(
        "health_days",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("device_uuid", sa.String(36), nullable=False),
        sa.Column("workout_date", sa.Date(), nullable=False),
        sa.Column("category", sa.String(40), nullable=False),
        sa.Column("symbol", sa.String(60), nullable=False),
        sa.Column("duration_minutes", sa.Integer(), nullable=False, server_default="0"),
    )
    op.create_index("ix_health_days_device_uuid", "health_days", ["device_uuid"])


def downgrade() -> None:
    op.drop_index("ix_health_days_device_uuid", table_name="health_days")
    op.drop_table("health_days")
    op.drop_table("profiles")
