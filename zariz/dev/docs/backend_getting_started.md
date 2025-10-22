# Backend - Getting Started

## Prerequisites

- Python 3.12+
- PostgreSQL 16+
- Redis 7+ (optional, for caching)
- Docker & Docker Compose (recommended)
- Git

## Project Structure

```
backend/
├── app/
│   ├── main.py              # FastAPI app entry
│   ├── config.py            # Settings
│   ├── api/
│   │   ├── v1/
│   │   │   ├── auth.py      # Auth endpoints
│   │   │   ├── orders.py    # Order CRUD
│   │   │   └── devices.py   # APNs device registry
│   ├── models/              # SQLAlchemy models
│   ├── schemas/             # Pydantic schemas
│   ├── services/            # Business logic
│   ├── db/                  # Database utilities
│   └── workers/             # Background tasks
├── alembic/                 # Database migrations
├── tests/
├── requirements.txt
└── docker-compose.yml
```

## Local Development Setup

### Option 1: Docker Compose (Recommended)

```bash
cd backend

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f api

# Stop services
docker-compose down
```

Services available:
- API: http://localhost:8000
- PostgreSQL: localhost:5432
- Redis: localhost:6379
- API Docs: http://localhost:8000/docs

### Option 2: Manual Setup

#### 1. Install Python Dependencies

```bash
cd backend

# Create virtual environment
python3.12 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt  # For development tools
```

#### 2. Setup PostgreSQL

```bash
# Install PostgreSQL
brew install postgresql@16  # macOS
# or: sudo apt install postgresql-16  # Ubuntu

# Start PostgreSQL
brew services start postgresql@16

# Create database
createdb zariz_dev

# Create user
psql postgres -c "CREATE USER zariz WITH PASSWORD 'dev_password';"
psql postgres -c "GRANT ALL PRIVILEGES ON DATABASE zariz_dev TO zariz;"
```

#### 3. Configure Environment

Create `.env` file:

```bash
# Database
DATABASE_URL=postgresql://zariz:dev_password@localhost:5432/zariz_dev

# JWT
SECRET_KEY=your-secret-key-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# APNs
APNS_KEY_ID=your-key-id
APNS_TEAM_ID=your-team-id
APNS_KEY_PATH=/path/to/AuthKey.p8
APNS_TOPIC=com.yourteam.zariz
APNS_USE_SANDBOX=true

# Redis (optional)
REDIS_URL=redis://localhost:6379/0

# Environment
ENVIRONMENT=development
DEBUG=true
```

#### 4. Run Migrations

```bash
# Generate migration (after model changes)
alembic revision --autogenerate -m "Initial schema"

# Apply migrations
alembic upgrade head

# Rollback
alembic downgrade -1
```

#### 5. Start Development Server

```bash
# With auto-reload
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# With multiple workers (production-like)
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

## CLI Commands

### Database Management

```bash
# Create migration
alembic revision --autogenerate -m "Add order status field"

# Apply migrations
alembic upgrade head

# Rollback one migration
alembic downgrade -1

# Show current version
alembic current

# Show migration history
alembic history
```

### Seed Data

```bash
# Create test data
python scripts/seed_db.py

# Create admin user
python scripts/create_admin.py --email admin@zariz.com --password admin123
```

### Run Tests

```bash
# All tests
pytest

# With coverage
pytest --cov=app --cov-report=html

# Specific test file
pytest tests/test_orders.py

# Specific test
pytest tests/test_orders.py::test_claim_order

# Watch mode
ptw -- tests/
```

### Code Quality

```bash
# Format code
black app/ tests/
isort app/ tests/

# Lint
ruff check app/ tests/
mypy app/

# All checks
pre-commit run --all-files
```

## API Documentation

### Interactive Docs

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- OpenAPI JSON: http://localhost:8000/openapi.json

### Key Endpoints

```bash
# Health check
curl http://localhost:8000/health

# Auth - Login
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone": "+1234567890", "code": "123456"}'

# Orders - List
curl http://localhost:8000/api/v1/orders?status=new \
  -H "Authorization: Bearer YOUR_TOKEN"

# Orders - Claim
curl -X POST http://localhost:8000/api/v1/orders/ORDER_ID/claim \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Idempotency-Key: unique-key-123"

# Orders - Update Status
curl -X POST http://localhost:8000/api/v1/orders/ORDER_ID/status \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "picked_up"}'
```

## Background Workers

### APNs Notification Worker

```bash
# Start worker
python -m app.workers.notifications

# Or with Celery
celery -A app.workers.celery_app worker --loglevel=info
```

### Scheduled Tasks

```bash
# Start scheduler
python -m app.workers.scheduler

# Or with Celery Beat
celery -A app.workers.celery_app beat --loglevel=info
```

## Database Operations

### Backup

```bash
# Backup database
pg_dump -U zariz zariz_dev > backup_$(date +%Y%m%d).sql

# Restore
psql -U zariz zariz_dev < backup_20251022.sql
```

### Reset Database

```bash
# Drop and recreate
dropdb zariz_dev
createdb zariz_dev
alembic upgrade head
python scripts/seed_db.py
```

## Monitoring & Debugging

### Logs

```bash
# View application logs
tail -f logs/app.log

# Docker logs
docker-compose logs -f api

# Filter by level
grep ERROR logs/app.log
```

### Database Queries

```bash
# Connect to database
psql postgresql://zariz:dev_password@localhost:5432/zariz_dev

# Useful queries
SELECT * FROM orders WHERE status = 'new';
SELECT * FROM order_events ORDER BY created_at DESC LIMIT 10;
```

### Performance Profiling

```python
# Add to endpoint for profiling
from fastapi import Request
import time

@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = str(process_time)
    return response
```

## Testing

### Unit Tests

```bash
# Run unit tests only
pytest tests/unit/

# With markers
pytest -m "not integration"
```

### Integration Tests

```bash
# Run integration tests
pytest tests/integration/

# With test database
TEST_DATABASE_URL=postgresql://zariz:dev_password@localhost:5432/zariz_test pytest
```

### Load Testing

```bash
# Install locust
pip install locust

# Run load test
locust -f tests/load/locustfile.py --host http://localhost:8000
```

## Deployment

### Build Docker Image

```bash
# Build
docker build -t zariz-backend:latest .

# Run
docker run -p 8000:8000 --env-file .env zariz-backend:latest

# Push to registry
docker tag zariz-backend:latest registry.example.com/zariz-backend:latest
docker push registry.example.com/zariz-backend:latest
```

### Deploy to VPS

```bash
# SSH to server
ssh user@your-vps-ip

# Pull latest code
cd /opt/zariz/backend
git pull origin main

# Rebuild and restart
docker-compose down
docker-compose up -d --build

# Check status
docker-compose ps
docker-compose logs -f api
```

### Deploy to Cloud Run (GCP)

```bash
# Install gcloud CLI
brew install google-cloud-sdk

# Authenticate
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Deploy
gcloud run deploy zariz-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars DATABASE_URL=$DATABASE_URL

# View logs
gcloud run logs read zariz-backend
```

### Deploy to Fly.io

```bash
# Install flyctl
brew install flyctl

# Login
flyctl auth login

# Initialize
flyctl launch

# Deploy
flyctl deploy

# View logs
flyctl logs
```

## Environment Variables

### Required

```bash
DATABASE_URL              # PostgreSQL connection string
SECRET_KEY               # JWT secret key
APNS_KEY_ID             # Apple Push Notifications key ID
APNS_TEAM_ID            # Apple Developer Team ID
APNS_KEY_PATH           # Path to .p8 key file
APNS_TOPIC              # App bundle ID
```

### Optional

```bash
REDIS_URL               # Redis connection string
SENTRY_DSN              # Sentry error tracking
LOG_LEVEL               # Logging level (DEBUG, INFO, WARNING, ERROR)
CORS_ORIGINS            # Allowed CORS origins
RATE_LIMIT_PER_MINUTE   # API rate limit
```

## Troubleshooting

### Database Connection Issues

```bash
# Check PostgreSQL is running
pg_isready

# Check connection
psql $DATABASE_URL -c "SELECT 1"

# Reset connections
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'zariz_dev';
```

### Migration Issues

```bash
# Check current version
alembic current

# Stamp to specific version
alembic stamp head

# Generate SQL without applying
alembic upgrade head --sql
```

### APNs Issues

```bash
# Test APNs connection
python scripts/test_apns.py --device-token YOUR_TOKEN

# Check certificate
openssl pkcs8 -in AuthKey.p8 -nocrypt -out key.pem
```

## Performance Optimization

### Database Indexes

```sql
-- Add indexes for common queries
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_courier_id ON orders(courier_id);
CREATE INDEX idx_order_events_order_id ON order_events(order_id);
```

### Query Optimization

```python
# Use select_related for joins
orders = await db.execute(
    select(Order).options(selectinload(Order.store))
)

# Pagination
orders = await db.execute(
    select(Order).limit(50).offset(page * 50)
)
```

### Caching

```python
from fastapi_cache import FastAPICache
from fastapi_cache.backends.redis import RedisBackend

# Setup cache
FastAPICache.init(RedisBackend(redis), prefix="zariz-cache")

# Use cache decorator
@cache(expire=60)
async def get_orders():
    return await db.execute(select(Order))
```

## Security Checklist

- [ ] Environment variables not committed
- [ ] JWT secret key is strong and unique
- [ ] Database credentials are secure
- [ ] HTTPS enforced in production
- [ ] CORS configured properly
- [ ] Rate limiting enabled
- [ ] SQL injection prevention (using ORM)
- [ ] Input validation with Pydantic
- [ ] Authentication on all protected endpoints
- [ ] Authorization checks (RBAC)

## Next Steps

1. Configure environment variables
2. Run migrations
3. Seed test data
4. Start development server
5. Test API endpoints
6. Setup APNs worker
7. Deploy to staging

## Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [SQLAlchemy Docs](https://docs.sqlalchemy.org/)
- [Alembic Tutorial](https://alembic.sqlalchemy.org/en/latest/tutorial.html)
- [PostgreSQL Manual](https://www.postgresql.org/docs/)
- [APNs Provider API](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server)
