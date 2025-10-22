# Zariz Runbooks

These runbooks describe common operational procedures.

## DB Restore
- Take a snapshot or SQL dump regularly (e.g., `pg_dump -Fc`).
- To restore: `pg_restore -d $DATABASE_URL backup.dump`.
- Verify migrations (`alembic current`) and app health after restore.

## Rotate JWT Secret
- Generate a new secret and set `JWT_SECRET`.
- Deploy with dual-token acceptance window if needed; otherwise schedule a maintenance window to log out all users.
- Monitor auth error rates; rollback if spike.

## APNs Key Rotation
- Create a new APNs key in Apple Developer portal.
- Update server config with new key ID/team ID and key file; restart notifier worker.
- Verify device token registration and send a test push.

## Scaling to Managed DB
- Provision a managed Postgres (e.g., 2–4 vCPU, 4–8GB RAM).
- Set connection string with SSL parameters.
- Increase pool size conservatively; monitor p95 latencies and saturation.

## Incident: Elevated 5xx
- Check recent deploys and error logs (Sentry if enabled).
- Inspect database metrics (connections, slow queries).
- If widespread: scale up instance or roll back.

## Health and SLOs
- Health endpoint: `GET /v1/orders?once=1` (SSE: `GET /v1/events/sse?once=1` returns `:ok`).
- SLOs: API p95 < 300ms; error rate < 1%; availability >= 99%.

