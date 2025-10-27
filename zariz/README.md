# Zariz

Full delivery ecosystem with iOS app, web admin, and backend API.

## Quick Start

### Prerequisites
- Docker Desktop
- Xcode 15+
- XcodeGen (`brew install xcodegen`)

### Start All Services

```bash
./run.sh start
```

Services:
- PostgreSQL on `localhost:5433`
- Backend API on `http://localhost:8000`
- Web Admin on `http://localhost:3002`
- Gorush push gateway on `http://localhost:8088`

### Configure iOS App

```bash
./run.sh ios:config
./run.sh ios:build
cd ios
open Zariz.xcodeproj
```

## Available Commands

### Service Management
- `./run.sh start` - Start all services
- `./run.sh stop` - Stop all services
- `./run.sh restart` - Restart all services
- `./run.sh build` - Rebuild Docker images
- `./run.sh clean` - Remove all containers and volumes

### Logs
- `./run.sh logs` - Show all logs
- `./run.sh logs backend` - Show backend logs only

### Database
- `./run.sh backend:migrate` - Run database migrations
- `./run.sh db:shell` - Open PostgreSQL shell

### Development
- `./run.sh backend:shell` - Open backend container shell
- `./run.sh ios:config` - Configure iOS app with local backend
- `./run.sh ios:build` - Generate Xcode project

## Project Structure

```
zariz/
├── backend/          # FastAPI backend
├── ios/              # iOS SwiftUI app
├── web-admin/        # Next.js admin panel
├── docker-compose.yml
└── run.sh
```

## API Endpoints

- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/docs
- Web Admin: http://localhost:3002

## Push Notifications

Gorush runs in mock mode by default. For real APNs:

1. Place `.p8` key in `zariz/dev/ops/gorush/keys/AuthKey.p8`
2. Set in `.env`:
```
APNS_KEY_ID=XXXXXX
APNS_TEAM_ID=YYYYYY
APNS_TOPIC=com.your.bundle.id
GORUSH_IOS_MOCK=false
APNS_USE_SANDBOX=1
```
3. Restart: `./run.sh restart`

## Troubleshooting

### Services won't start
```bash
./run.sh clean
./run.sh build
./run.sh start
```

### Database issues
```bash
./run.sh stop
docker volume rm zariz_postgres_data
./run.sh start
```
