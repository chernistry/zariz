"""add store admin fields

Revision ID: c3d4e5f6a8b9
Revises: b2c3d4e5f6a7
Create Date: 2025-10-23 12:05:00

"""
from alembic import op
import sqlalchemy as sa


revision = 'c3d4e5f6a8b9'
down_revision = 'b2c3d4e5f6a7'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('stores', sa.Column('status', sa.String(length=16), nullable=True))
    op.add_column('stores', sa.Column('pickup_address', sa.String(length=255), nullable=True))
    op.add_column('stores', sa.Column('box_limit', sa.Integer(), nullable=True))
    op.add_column('stores', sa.Column('hours_text', sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column('stores', 'hours_text')
    op.drop_column('stores', 'box_limit')
    op.drop_column('stores', 'pickup_address')
    op.drop_column('stores', 'status')

