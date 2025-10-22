.PHONY: up down logs

# iOS helpers
.PHONY: ios-xcodeproj
ios-xcodeproj:
	@which xcodegen >/dev/null || (echo "Installing xcodegen via Homebrew..." && brew install xcodegen)
	cd zariz/ios && xcodegen generate
	@echo "Open the project: zariz/ios/Zariz.xcodeproj"

DOCKER_COMPOSE := $(shell command -v docker-compose >/dev/null 2>&1 && echo docker-compose || echo docker compose)

up:
	$(DOCKER_COMPOSE) up -d

down:
	$(DOCKER_COMPOSE) down -v

logs:
	$(DOCKER_COMPOSE) logs -f --tail=200
