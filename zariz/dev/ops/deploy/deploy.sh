#!/usr/bin/env bash
set -euo pipefail

# Usage: HOST=user@server ./deploy.sh [TAG]
# Requires: passwordless SSH or agent; remote path defaults to /opt/zariz

HOST=${HOST:-}
TAG=${1:-latest}
REMOTE_DIR=${REMOTE_DIR:-/opt/zariz}

if [[ -z "$HOST" ]]; then
  echo "HOST env var is required (e.g., user@server)" >&2
  exit 1
fi

ssh "$HOST" bash -c "'
  set -e
  cd "$REMOTE_DIR"
  # Replace image tag in compose for api service
  sed -i.bak -E "s|(ghcr.io/.*/zariz-api:)[^"\n]+|\1'"$TAG"'|" zariz/dev/ops/compose/prod.yml || true
  docker compose -f zariz/dev/ops/compose/prod.yml pull
  docker compose -f zariz/dev/ops/compose/prod.yml up -d --remove-orphans
'"

echo "Deployed tag $TAG to $HOST:$REMOTE_DIR"

