#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/config.env"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" down --remove-orphans