"""rename claimed to accepted

Revision ID: rename_claimed_to_accepted
Revises: c3d4e5f6a8b9
Create Date: 2025-01-24 16:35:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'rename_claimed_to_accepted'
down_revision = 'c3d4e5f6a8b9'

def upgrade():
    # Update order statuses
    op.execute("UPDATE orders SET status = 'accepted' WHERE status = 'claimed'")
    # Update order_events types
    op.execute("UPDATE order_events SET type = 'accepted' WHERE type = 'claimed'")


def downgrade():
    op.execute("UPDATE orders SET status = 'claimed' WHERE status = 'accepted'")
    op.execute("UPDATE order_events SET type = 'claimed' WHERE type = 'accepted'")
