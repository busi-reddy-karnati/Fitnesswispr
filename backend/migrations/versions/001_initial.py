"""Initial schema: create all tables

Revision ID: 001
Revises: 
Create Date: 2026-06-15 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # workout_sessions
    # ------------------------------------------------------------------
    op.create_table(
        "workout_sessions",
        sa.Column(
            "session_id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("device_uuid", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("workout_date", sa.Date(), nullable=False),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.TIMESTAMP(timezone=True),
            nullable=True,
        ),
        sa.Column("source", sa.VARCHAR(20), nullable=False, server_default="voice"),
        sa.Column("raw_transcript", sa.Text(), nullable=True),
        sa.Column("body_weight_lbs", sa.Numeric(5, 1), nullable=True),
        sa.Column("workout_type", sa.VARCHAR(30), nullable=True),
        sa.Column("cardio_notes", sa.Text(), nullable=True),
        sa.Column("session_notes", sa.Text(), nullable=True),
        sa.Column("duration_minutes", sa.Integer(), nullable=True),
    )
    op.create_index(
        "ix_workout_sessions_device_uuid", "workout_sessions", ["device_uuid"]
    )
    op.create_index(
        "ix_workout_sessions_workout_date", "workout_sessions", ["workout_date"]
    )

    # ------------------------------------------------------------------
    # exercises
    # ------------------------------------------------------------------
    op.create_table(
        "exercises",
        sa.Column(
            "exercise_id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "session_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey(
                "workout_sessions.session_id",
                ondelete="CASCADE",
                name="fk_exercises_session_id",
            ),
            nullable=False,
        ),
        sa.Column("exercise_order", sa.SmallInteger(), nullable=False, server_default="0"),
        sa.Column("name", sa.VARCHAR(200), nullable=False),
        sa.Column("equipment", sa.VARCHAR(100), nullable=True),
        sa.Column("muscle_group", sa.VARCHAR(100), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
    )

    # ------------------------------------------------------------------
    # exercise_sets
    # ------------------------------------------------------------------
    op.create_table(
        "exercise_sets",
        sa.Column(
            "set_id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "exercise_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey(
                "exercises.exercise_id",
                ondelete="CASCADE",
                name="fk_exercise_sets_exercise_id",
            ),
            nullable=False,
        ),
        sa.Column("set_number", sa.SmallInteger(), nullable=False),
        sa.Column("reps", sa.SmallInteger(), nullable=True),
        sa.Column("weight", sa.Numeric(6, 2), nullable=True),
        sa.Column("weight_unit", sa.VARCHAR(3), nullable=False, server_default="lbs"),
        sa.Column("duration_seconds", sa.Integer(), nullable=True),
    )

    # ------------------------------------------------------------------
    # device_context
    # ------------------------------------------------------------------
    op.create_table(
        "device_context",
        sa.Column(
            "device_uuid",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column("last_body_weight_lbs", sa.Numeric(5, 1), nullable=True),
        sa.Column(
            "last_updated",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_table("device_context")
    op.drop_table("exercise_sets")
    op.drop_table("exercises")
    op.drop_index("ix_workout_sessions_workout_date", table_name="workout_sessions")
    op.drop_index("ix_workout_sessions_device_uuid", table_name="workout_sessions")
    op.drop_table("workout_sessions")
