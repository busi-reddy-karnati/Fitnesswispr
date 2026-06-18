"""Add users table for Sign in with Apple accounts

Revision ID: 002
Revises: 001
Create Date: 2026-06-16 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "002"
down_revision: Union[str, None] = "001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("user_id", sa.String(36), primary_key=True),
        sa.Column("apple_sub", sa.String(255), nullable=False),
        sa.Column("email", sa.String(320), nullable=True),
        sa.Column("full_name", sa.String(200), nullable=True),
        sa.Column("primary_uuid", sa.String(36), nullable=False),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_unique_constraint("uq_users_apple_sub", "users", ["apple_sub"])


def downgrade() -> None:
    op.drop_constraint("uq_users_apple_sub", "users", type_="unique")
    op.drop_table("users")
