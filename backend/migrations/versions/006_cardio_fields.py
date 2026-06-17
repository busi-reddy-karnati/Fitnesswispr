"""Add structured cardio fields to workout_sessions

Revision ID: 006
Revises: 005
Create Date: 2026-06-17 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "006"
down_revision: Union[str, None] = "005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "workout_sessions",
        sa.Column("cardio_activity", sa.String(40), nullable=True),
    )
    op.add_column(
        "workout_sessions",
        sa.Column("cardio_distance", sa.Numeric(7, 2), nullable=True),
    )
    op.add_column(
        "workout_sessions",
        sa.Column("cardio_distance_unit", sa.String(8), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("workout_sessions", "cardio_distance_unit")
    op.drop_column("workout_sessions", "cardio_distance")
    op.drop_column("workout_sessions", "cardio_activity")
