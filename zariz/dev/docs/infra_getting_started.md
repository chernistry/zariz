# Infrastructure & Deployment - Getting Started

## Overview

This guide covers deploying the complete Zariz stack: backend API, PostgreSQL, web panel, and supporting services.

## Architecture

```
┌─────────────┐
│   iOS App   │
└──────┬──────┘
       │
       │ HTTPS
       ▼
┌─────────────────────────────────────┐
│         Load Balancer/Proxy         │
│      (Nginx/Caddy/Cloudflare)       │
└──────┬──────────────────────┬───────┘
       │                      │
       │ /api/*              │ /*
       ▼                      ▼
┌─────────────┐        ┌─────────────┐
│   Backend   │        │  Web Panel  │
│  (FastAPI)  │        │  (Next.js)  │
└──────┬──────┘        └─────────────┘
       │
       ▼
┌─────────────┐        ┌─────────────┐
│ PostgreSQL  │        │    Redis    │
└─────────────┘        └─────────────┘
       │
       ▼
┌─────────────┐
│ APNs Worker │
└─────────────┘
```

## Deployment Options

### Option 1: Single VPS (Recommended for MVP)

**Best for**: MVP, small scale (< 500 users), budget-conscious

**Providers**:
- Hetzner Cloud: €4.51/month (2 vCPU, 4GB RAM)
- DigitalOcean: $6/month (1 vCPU, 1GB RAM)
- Oracle Cloud: Free tier (4 OCPU, 24GB RAM on ARM)

### Option 2: PaaS (Easiest)

**Best for**: Quick deployment, no DevOps experience

**Providers**:
- Railway: $5/month + usage
- Fly.io: Free tier available
- Render: Free tier for web services

### Option 3: Cloud (Scalable)

**Best for**: Production, high scale, enterprise

**Providers**:
- Google Cloud Run + Cloud SQL
- AWS ECS + RDS
- Azure Container Apps + PostgreSQL

## Single VPS Deployment (Docker Compose)

### Prerequisites

```bash
# VPS with:
- Ubuntu 22.04 LTS
- 2+ vCPU, 4GB+ RAM
- 20GB+ storage
- Public IP address
- Domain name (optional but recommended)
```

### 1. Initial Server Setup

```bash
# SSH into server
ssh root@your-server-ip

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
apt install docker-compose-plugin -y

# Create non-root user
adduser zariz
usermod -aG docker zariz
su - zariz
```

### 2. Setup Project

```bash
# Clone repository
git clone https://github.com/yourorg/zariz.git
cd zariz

# Create environment file
cp .env.example .env
nano .env  # Edit with your values
```

### 3. Docker Compose Configuration

**docker-compose.yml**:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: zariz
      POSTGRES_USER: zariz
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U zariz"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  backend:
    build: ./backend
    environment:
      DATABASE_URL: postgresql://zariz:${DB_PASSWORD}@postgres:5432/zariz
      REDIS_URL: redis://redis:6379/0
      SECRET_KEY: ${SECRET_KEY}
      APNS_KEY_ID: ${APNS_KEY_ID}
      APNS_TEAM_ID: ${APNS_TEAM_ID}
      APNS_KEY_PATH: /app/keys/AuthKey.p8
    volumes:
      - ./backend/keys:/app/keys:ro
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  worker:
    build: ./backend
    command: python -m app.workers.notifications
    environment:
      DATABASE_URL: postgresql://zariz:${DB_PASSWORD}@postgres:5432/zariz
      REDIS_URL: redis://redis:6379/0
      APNS_KEY_ID: ${APNS_KEY_ID}
      APNS_TEAM_ID: ${APNS_TEAM_ID}
      APNS_KEY_PATH: /app/keys/AuthKey.p8
    volumes:
      - ./backend/keys:/app/keys:ro
    depends_on:
      - postgres
      - redis
    restart: unless-stopped

  web:
    build: ./web
    environment:
      NEXT_PUBLIC_API_URL: https://api.yourdomain.com/api/v1
      NEXTAUTH_URL: https://dashboard.yourdomain.com
      NEXTAUTH_SECRET: ${NEXTAUTH_SECRET}
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - certbot_data:/var/www/certbot:ro
    depends_on:
      - backend
      - web
    restart: unless-stopped

  certbot:
    image: certbot/certbot
    volumes:
      - certbot_data:/var/www/certbot
      - ./nginx/ssl:/etc/letsencrypt
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"

volumes:
  postgres_data:
  certbot_data:
```

### 4. Nginx Configuration

**nginx/nginx.conf**:

```nginx
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server backend:8000;
    }

    upstream web {
        server web:3000;
    }

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name api.yourdomain.com dashboard.yourdomain.com;
        
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        location / {
            return 301 https://$host$request_uri;
        }
    }

    # API Server
    server {
        listen 443 ssl http2;
        server_name api.yourdomain.com;

        ssl_certificate /etc/nginx/ssl/live/api.yourdomain.com/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/live/api.yourdomain.com/privkey.pem;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }

    # Web Dashboard
    server {
        listen 443 ssl http2;
        server_name dashboard.yourdomain.com;

        ssl_certificate /etc/nginx/ssl/live/dashboard.yourdomain.com/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/live/dashboard.yourdomain.com/privkey.pem;

        location / {
            proxy_pass http://web;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```

### 5. SSL Certificates

```bash
# Initial certificate
docker-compose run --rm certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  -d api.yourdomain.com \
  -d dashboard.yourdomain.com \
  --email your@email.com \
  --agree-tos \
  --no-eff-email

# Reload nginx
docker-compose exec nginx nginx -s reload
```

### 6. Deploy

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check status
docker-compose ps

# Run migrations
docker-compose exec backend alembic upgrade head

# Create admin user
docker-compose exec backend python scripts/create_admin.py
```

### 7. Monitoring

```bash
# View logs
docker-compose logs -f backend
docker-compose logs -f worker

# Check resource usage
docker stats

# Database backup
docker-compose exec postgres pg_dump -U zariz zariz > backup.sql
```

## Alternative: Caddy (Simpler SSL)

**Caddyfile**:

```caddy
api.yourdomain.com {
    reverse_proxy backend:8000
}

dashboard.yourdomain.com {
    reverse_proxy web:3000
}
```

**docker-compose.yml** (replace nginx):

```yaml
  caddy:
    image: caddy:2-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - backend
      - web
    restart: unless-stopped

volumes:
  caddy_data:
  caddy_config:
```

## Deploy to Railway

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Initialize project
railway init

# Link services
railway link

# Deploy backend
cd backend
railway up

# Deploy web
cd ../web
railway up

# Add PostgreSQL
railway add --plugin postgresql

# Set environment variables
railway variables set SECRET_KEY=your-secret-key
```

## Deploy to Fly.io

### Backend

```bash
# Install flyctl
brew install flyctl

# Login
flyctl auth login

# Initialize
cd backend
flyctl launch

# Add PostgreSQL
flyctl postgres create

# Attach database
flyctl postgres attach <postgres-app-name>

# Deploy
flyctl deploy

# View logs
flyctl logs
```

**fly.toml**:

```toml
app = "zariz-backend"
primary_region = "iad"

[build]
  dockerfile = "Dockerfile"

[env]
  PORT = "8000"

[[services]]
  internal_port = 8000
  protocol = "tcp"

  [[services.ports]]
    port = 80
    handlers = ["http"]

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]
```

### Web

```bash
cd web
flyctl launch
flyctl deploy
```

## Deploy to Google Cloud Run

```bash
# Install gcloud
brew install google-cloud-sdk

# Authenticate
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Create Cloud SQL instance
gcloud sql instances create zariz-db \
  --database-version=POSTGRES_16 \
  --tier=db-f1-micro \
  --region=us-central1

# Deploy backend
cd backend
gcloud run deploy zariz-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --add-cloudsql-instances YOUR_PROJECT_ID:us-central1:zariz-db \
  --set-env-vars DATABASE_URL=$DATABASE_URL

# Deploy web
cd ../web
gcloud run deploy zariz-web \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```

## CI/CD with GitHub Actions

**.github/workflows/deploy.yml**:

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build and push Docker image
        run: |
          echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
          docker build -t yourorg/zariz-backend:latest ./backend
          docker push yourorg/zariz-backend:latest
      
      - name: Deploy to VPS
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.VPS_HOST }}
          username: ${{ secrets.VPS_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            cd /opt/zariz
            docker-compose pull
            docker-compose up -d
            docker-compose exec backend alembic upgrade head

  deploy-web:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: ./web
```

## Monitoring & Observability

### Prometheus + Grafana

**docker-compose.yml** (add):

```yaml
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    restart: unless-stopped

  grafana:
    image: grafana/grafana
    ports:
      - "3001:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD}
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
```

### Sentry

```bash
# Backend
pip install sentry-sdk[fastapi]

# Web
npm install @sentry/nextjs
npx @sentry/wizard@latest -i nextjs
```

## Backup Strategy

### Automated Backups

```bash
#!/bin/bash
# backup.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups"

# Database backup
docker-compose exec -T postgres pg_dump -U zariz zariz | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# Upload to S3
aws s3 cp $BACKUP_DIR/db_$DATE.sql.gz s3://zariz-backups/

# Keep only last 7 days
find $BACKUP_DIR -name "db_*.sql.gz" -mtime +7 -delete
```

**Cron job**:

```bash
# Run daily at 2 AM
0 2 * * * /opt/zariz/backup.sh
```

## Security Hardening

### Firewall

```bash
# UFW
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

### Fail2Ban

```bash
apt install fail2ban
systemctl enable fail2ban
systemctl start fail2ban
```

### Docker Security

```yaml
# docker-compose.yml
services:
  backend:
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp
```

## Scaling

### Horizontal Scaling

```yaml
# docker-compose.yml
services:
  backend:
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

### Load Balancing

```nginx
upstream backend {
    least_conn;
    server backend1:8000;
    server backend2:8000;
    server backend3:8000;
}
```

## Troubleshooting

### Check Service Health

```bash
# All services
docker-compose ps

# Specific service logs
docker-compose logs -f backend

# Enter container
docker-compose exec backend bash
```

### Database Issues

```bash
# Connect to database
docker-compose exec postgres psql -U zariz

# Check connections
SELECT * FROM pg_stat_activity;

# Restart database
docker-compose restart postgres
```

### SSL Certificate Issues

```bash
# Test certificate
openssl s_client -connect api.yourdomain.com:443

# Renew manually
docker-compose run --rm certbot renew

# Check expiry
echo | openssl s_client -servername api.yourdomain.com -connect api.yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates
```

## Cost Estimation

### Single VPS (Hetzner)
- VPS: €4.51/month
- Domain: €10/year
- **Total: ~€5/month**

### PaaS (Railway)
- Backend: $5/month
- Database: $5/month
- Web: Free (Vercel)
- **Total: ~$10/month**

### Cloud (GCP)
- Cloud Run: $5-20/month
- Cloud SQL: $10-30/month
- Load Balancer: $18/month
- **Total: ~$35-70/month**

## Next Steps

1. Choose deployment option
2. Setup domain and DNS
3. Configure environment variables
4. Deploy services
5. Setup SSL certificates
6. Configure monitoring
7. Setup backups
8. Test end-to-end

## Resources

- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Railway Docs](https://docs.railway.app/)
- [Fly.io Docs](https://fly.io/docs/)
- [Google Cloud Run](https://cloud.google.com/run/docs)
