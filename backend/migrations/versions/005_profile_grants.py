"""Add profile_grants table (spotter access registry)

Revision ID: 005
Revises: 004
Create Date: 2026-06-16 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "005"
down_revision: Union[str, None] = "004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "profile_grants",
        sa.Column("owner_uuid", sa.String(36), nullable=False),
        sa.Column("grantee_uuid", sa.String(36), nullable=False),
        sa.Column("access", sa.String(10), nullable=False, server_default="read"),
        sa.Column("grantee_name", sa.String(200), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("owner_uuid", "grantee_uuid"),
    )
    op.create_index(
        "ix_profile_grants_grantee", "profile_grants", ["grantee_uuid"]
    )


def downgrade() -> None:
    op.drop_index("ix_profile_grants_grantee", table_name="profile_grants")
    op.drop_table("profile_grants")
