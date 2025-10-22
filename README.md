# Zariz - Courier Delivery Tracking System

**A complete iOS application and web platform for tracking courier deliveries from stores**

## 🚀 What is Zariz?

Zariz is a mobile and web application designed to streamline the courier delivery process. The system connects stores, couriers, and administrators in a unified platform where stores can create delivery orders, couriers can claim and track these orders, and administrators can monitor the entire operation.

### Key Features
- **For Stores**: Create delivery orders and monitor their status through a web dashboard
- **For Couriers**: View, claim, and update delivery status via an iOS app
- **For Administrators**: Manage users and monitor all activities across the system

## 🛠️ Technology Stack

### Backend
- **Framework**: FastAPI (Python 3.12)
- **Database**: PostgreSQL with SQLAlchemy and Alembic
- **Authentication**: JWT-based with role-based access control (RBAC)
- **API**: RESTful endpoints with OpenAPI 3.1 specification

### iOS Application
- **Framework**: SwiftUI with MVVM architecture
- **Data**: SwiftData for local caching and offline support
- **Security**: Keychain with biometric authentication
- **Real-time Updates**: Silent APNs pushes with background tasks

### Web Panel
- **Framework**: Next.js with TypeScript
- **Real-time**: Server-Sent Events (SSE) for live order updates
- **Authentication**: Secure role-based access for stores and admins

## 📋 Project Structure

```
zariz/
├── backend/           # FastAPI backend services
├── ios/              # iOS application (SwiftUI)
├── web/              # Admin web panel (Next.js)
├── dev/              # Development artifacts, tickets, and roadmap
├── docker/           # Container configurations
└── tests/            # Test suite
```

## 🎯 How It Works

1. **Store Creates Order**: Store users log into the web dashboard to create new delivery orders with pickup/dropoff addresses and item details
2. **Courier Claims Order**: Courier receives notifications via the iOS app and can claim available orders
3. **Track Delivery**: Courier updates the order status (claimed → picked_up → delivered) through the app
4. **Real-time Monitoring**: Both stores and administrators can monitor delivery progress in real-time

## 📝 Development Status

- **Current Phase**: Active development
- **MVP Scope**: Core functionality without geolocation
- **Progress**: See [roadmap](dev/tickets/roadmap.md) for detailed progress tracking

## 🤝 Contributing

The project is designed as a solo development effort with AI assistance. Tickets are tracked in the `dev/tickets/` directory and follow a structured workflow:

- **Open Tickets**: [tickets/open/](dev/tickets/open/) - Current tasks to be completed
- **Completed**: [tickets/closed/](dev/tickets/closed/) - Finished work items
- **Roadmap**: [tickets/roadmap.md](dev/tickets/roadmap.md) - Overall project timeline and estimates

## 🏗️ Architecture Highlights

- **Atomic Order Claims**: Ensures only one courier can claim an order using PostgreSQL transactions
- **Idempotency**: All write operations include Idempotency-Key headers to handle retries safely
- **Offline Support**: iOS app can work offline with SwiftData caching and sync when online
- **Rate Limiting**: API includes proper rate limiting and error handling
- **Security**: JWT authentication, BOLA protection, and OWASP API security best practices

## 📊 Non-functional Requirements

- **Performance**: API response time under 300ms (p95 percentile)
- **Scalability**: Supports up to 100 couriers and 50 stores
- **Reliability**: 99% uptime SLA
- **Security**: JWT authentication, HTTPS, and proper authorization checks

## 🚀 Getting Started

Choose your component to get started:

- **[iOS App Setup](zariz/dev/docs/ios_getting_started.md)** - Build and run the iOS application
- **[Backend Setup](zariz/dev/docs/backend_getting_started.md)** - Run the FastAPI backend locally or deploy
- **[Web Panel Setup](zariz/dev/docs/web_getting_started.md)** - Set up the store dashboard
- **[Infrastructure & Deployment](zariz/dev/docs/infra_getting_started.md)** - Deploy the complete stack

### Quick Start (All Components)

```bash
# Clone and setup
git clone <repository-url>
cd zariz

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

## 📚 Resources

- [Technical Specification](dev/tech_task.md) - Complete system requirements
- [Development Roadmap](dev/tickets/roadmap.md) - Project timeline and progress
- [Coding Rules](dev/tickets/coding_rules.md) - Development standards
- [Best Practices](dev/best_practices.md) - Implementation guidelines

---

*Developed with FastAPI, SwiftUI, and Next.js following modern software engineering practices and security standards.*