# Zariz

Delivery management system with iOS app, web admin, and backend API.

## Quick Start

### Prerequisites
- Docker Desktop
- Xcode 15+ (for iOS development)
- XcodeGen (`brew install xcodegen`)

### Start All Services

```bash
./run.sh start
```

This will start:
- **PostgreSQL** on `localhost:5432`
- **Backend API** on `http://localhost:8000`
- **Web Admin** on `http://localhost:3000`

### Configure iOS App

```bash
./run.sh ios:config
```

This configures the iOS app to connect to your local backend.

### Build iOS Project

```bash
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
- `./run.sh logs postgres` - Show database logs only
- `./run.sh logs web-admin` - Show web admin logs only

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
└── run.sh           # Management script
```

## API Endpoints

- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/docs
- Web Admin: http://localhost:3000

## iOS Development

The iOS app is configured to use your local IP address for backend connectivity, allowing you to test on physical devices.

To change the backend URL manually, edit:
```
ios/Zariz/Data/API/Config.swift
```

## Environment Variables

Backend environment variables are configured in `docker-compose.yml`:
- `POSTGRES_USER=zariz`
- `POSTGRES_PASSWORD=zariz`
- `POSTGRES_DB=zariz`
- `API_JWT_SECRET=dev_secret_change_me_in_production`

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

### iOS build issues
```bash
cd ios
xcodegen generate
```
