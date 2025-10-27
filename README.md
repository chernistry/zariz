# Zariz

Full delivery ecosystem with iOS app, web admin, and backend API.

## Overview

Zariz connects stores, couriers, and administrators in a unified platform. Stores create delivery orders, couriers claim and track orders via iOS app, and administrators monitor operations.

### Key Features
- **Stores**: Create delivery orders and monitor status through web dashboard
- **Couriers**: View, claim, and update delivery status via iOS app
- **Administrators**: Manage users and monitor all activities

## Technology Stack

### Backend
- FastAPI (Python 3.12)
- PostgreSQL with SQLAlchemy and Alembic
- JWT authentication with RBAC
- RESTful API with OpenAPI 3.1

### iOS Application
- SwiftUI with MVVM architecture
- SwiftData for local caching and offline support
- Keychain with biometric authentication
- Silent APNs pushes with background tasks

### Web Panel
- Next.js with TypeScript
- Server-Sent Events (SSE) for live order updates
- Role-based access for stores and admins

## Project Structure

```
zariz/
├── backend/           # FastAPI backend services
├── ios/              # iOS application (SwiftUI)
├── web/              # Admin web panel (Next.js)
├── dev/              # Development artifacts, tickets, and roadmap
├── docker/           # Container configurations
└── tests/            # Test suite
```

## How It Works

1. **Store Creates Order**: Store users log into web dashboard to create delivery orders
2. **Courier Claims Order**: Courier receives notifications and claims available orders
3. **Track Delivery**: Courier updates order status (claimed → picked_up → delivered)
4. **Real-time Monitoring**: Stores and administrators monitor delivery progress in real-time

## Architecture Highlights

- **Atomic Order Claims**: PostgreSQL transactions ensure only one courier can claim an order
- **Idempotency**: All write operations include Idempotency-Key headers
- **Offline Support**: iOS app works offline with SwiftData caching
- **Rate Limiting**: API includes rate limiting and error handling
- **Security**: JWT authentication, BOLA protection, OWASP API security best practices

## Getting Started

### Quick Start (All Components)

```bash
# Backend
cd backend && python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload

# Web (separate terminal)
cd web && npm install && npm run dev

# iOS - open in Xcode
open ios/Zariz.xcodeproj
```

## Observability

- Backend logs are JSON-formatted with request IDs and latency metrics
- Optional OpenTelemetry tracing (set `OTEL_ENABLED=1`)
- Optional Sentry error tracking (set `SENTRY_DSN`)
- See runbooks: `zariz/dev/docs/runbooks.md`

## Resources

- [Technical Specification](dev/tech_task.md)
- [Development Roadmap](dev/tickets/roadmap.md)
- [Coding Rules](dev/tickets/coding_rules.md)
- [Best Practices](dev/best_practices.md)
