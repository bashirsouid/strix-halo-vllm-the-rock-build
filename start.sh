#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/config.env"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

require_cmd docker
require_cmd curl

mkdir -p \
  "${HF_CACHE_DIR}" \
  "${VLLM_CACHE_DIR}" \
  "${MODEL_DIR}"

cd "${SCRIPT_DIR}"

echo "==> Building and starting ${CONTAINER_NAME}"
echo "    Base image : ${VLLM_BASE_IMAGE}"
echo "    Smart model: ${VLLM_SMART_MODEL}"
echo "    Draft model: ${VLLM_DRAFT_MODEL}"
echo "    Model dir  : ${MODEL_DIR}"

# Only pass --build if the local image doesn't exist yet.
# To force a rebuild: docker rmi strix-vllm-mistral:local
if docker image inspect "${LOCAL_IMAGE:-strix-vllm-mistral:local}" >/dev/null 2>&1; then
  echo "    Image      : ${LOCAL_IMAGE:-strix-vllm-mistral:local} found, skipping build"
  docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d
else
  echo "    Image      : ${LOCAL_IMAGE:-strix-vllm-mistral:local} not found, building..."
  docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d --build
fi

READY_URL="http://127.0.0.1:${SERVER_PORT}/v1/models"
TIMEOUT_SECONDS=720
SLEEP_SECONDS=5
ELAPSED=0

echo "==> Waiting for vLLM API at ${READY_URL}"
until curl -fsS "${READY_URL}" >/dev/null 2>&1; do
  if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
    echo "Container exited before becoming ready. Showing logs:" >&2
    docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" logs --tail=200
    exit 1
  fi

  if (( ELAPSED >= TIMEOUT_SECONDS )); then
    echo "Timed out waiting for vLLM to become ready. Showing recent logs:" >&2
    docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" logs --tail=200
    exit 1
  fi

  sleep "${SLEEP_SECONDS}"
  ELAPSED=$((ELAPSED + SLEEP_SECONDS))
done

echo ""
echo "✓ vLLM is ready"
echo "  OpenAI API base : http://127.0.0.1:${SERVER_PORT}/v1"
echo "  Models endpoint : ${READY_URL}"
echo ""
echo "Tip: first launch will spend time downloading weights and compiling ROCm kernels."
echo "     Subsequent starts skip the build and load much faster."