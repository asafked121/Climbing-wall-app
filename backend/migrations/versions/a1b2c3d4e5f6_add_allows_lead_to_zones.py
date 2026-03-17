"""add allows_lead to zones

Revision ID: a1b2c3d4e5f6
Revises: 4b56797079f3
Create Date: 2026-03-16 20:55:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, Sequence[str], None] = '4b56797079f3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add column with default False
    with op.batch_alter_table('zones', schema=None) as batch_op:
        batch_op.add_column(sa.Column('allows_lead', sa.Boolean(), nullable=False, server_default=sa.text('0')))

    # Seed existing lead zones: Rope 1 (4), Rope 4 (7), Rope 6 (9)
    op.execute("UPDATE zones SET allows_lead = 1 WHERE id IN (4, 7, 9)")


def downgrade() -> None:
    with op.batch_alter_table('zones', schema=None) as batch_op:
        batch_op.drop_column('allows_lead')
