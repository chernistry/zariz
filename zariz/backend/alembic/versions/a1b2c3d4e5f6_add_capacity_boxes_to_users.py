"""add capacity_boxes to users

Revision ID: a1b2c3d4e5f6
Revises: cb2739349b88
Create Date: 2025-10-23 11:20:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'a1b2c3d4e5f6'
down_revision = 'cb2739349b88'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'users',
        sa.Column('capacity_boxes', sa.Integer(), nullable=False, server_default='8'),
    )


def downgrade() -> None:
    op.drop_column('users', 'capacity_boxes')

