#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$PROJECT_ROOT/ios"

cd "$PROJECT_ROOT"

case "$1" in
  start)
    echo "Starting all services (postgres, backend, web-admin)..."
    docker compose up -d
    echo "Services started!"
    echo "Backend: http://localhost:8000"
    echo "Web Admin: http://localhost:3000"
    ;;
    
  stop)
    echo "Stopping all services..."
    docker compose down
    echo "Services stopped!"
    ;;
    
  restart)
    echo "Restarting all services..."
    docker compose restart
    echo "Services restarted!"
    ;;
    
  logs)
    SERVICE="${2:-}"
    if [ -z "$SERVICE" ]; then
      docker compose logs -f
    else
      docker compose logs -f "$SERVICE"
    fi
    ;;
    
  build)
    echo "Building Docker images..."
    docker compose build
    echo "Build complete!"
    ;;
    
  backend:migrate)
    echo "Running database migrations..."
    docker compose exec backend alembic upgrade head
    echo "Migrations complete!"
    ;;
    
  backend:shell)
    echo "Opening backend shell..."
    docker compose exec backend sh
    ;;
    
  db:shell)
    echo "Opening PostgreSQL shell..."
    docker compose exec postgres psql -U zariz -d zariz
    ;;
    
  ios:config)
    LOCAL_IP=$(ipconfig getifaddr en0 || echo "127.0.0.1")
    echo "Configuring iOS app to use backend at http://$LOCAL_IP:8000/v1"
    cat > "$IOS_DIR/Zariz/Data/API/Config.swift" << EOF
import Foundation

enum AppConfig {
    static let baseURL = URL(string: "http://$LOCAL_IP:8000/v1")!
    static let defaultPickupAddress = "Main Warehouse"
}
EOF
    echo "iOS config updated!"
    ;;
    
  ios:build)
    echo "Building iOS project..."
    cd "$IOS_DIR"
    xcodegen generate
    echo "iOS project generated!"
    ;;
    
  clean)
    echo "Stopping and removing all containers, volumes..."
    docker compose down -v
    echo "Cleanup complete!"
    ;;
    
  *)
    echo "Usage: ./run.sh {command}"
    echo ""
    echo "Commands:"
    echo "  start              - Start all services (postgres, backend, web-admin)"
    echo "  stop               - Stop all services"
    echo "  restart            - Restart all services"
    echo "  logs [service]     - Show logs (optionally for specific service)"
    echo "  build              - Build Docker images"
    echo "  backend:migrate    - Run database migrations"
    echo "  backend:shell      - Open backend container shell"
    echo "  db:shell           - Open PostgreSQL shell"
    echo "  ios:config         - Configure iOS app with local backend URL"
    echo "  ios:build          - Generate Xcode project"
    echo "  clean              - Stop and remove all containers and volumes"
    exit 1
    ;;
esac
