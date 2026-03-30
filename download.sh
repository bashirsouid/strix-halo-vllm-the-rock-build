#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/config.env"
  set +a
fi

SMART_MODEL="${VLLM_SMART_MODEL:-cyankiwi/Mistral-Small-4-119B-2603-AWQ-4bit}"
DRAFT_MODEL="${VLLM_DRAFT_MODEL:-mistralai/Mistral-Small-4-119B-2603-eagle}"

HF_HOME="${HF_HOME:-/mnt/data/hf-cache}"
HF_HUB_CACHE="${HF_HUB_CACHE:-${HF_HOME%/}/hub}"
HF_DOWNLOAD_WORKERS="${HF_DOWNLOAD_WORKERS:-8}"

export SMART_MODEL
export DRAFT_MODEL
export HF_HOME
export HF_HUB_CACHE
export HF_DOWNLOAD_WORKERS
export HF_HUB_ENABLE_HF_TRANSFER="${HF_HUB_ENABLE_HF_TRANSFER:-1}"
export PYTHONUNBUFFERED=1

mkdir -p "${HF_HOME}" "${HF_HUB_CACHE}"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need_cmd python3

if ! python3 - <<'PY' >/dev/null 2>&1
import huggingface_hub
PY
then
  log "huggingface_hub not found, installing it for this user..."
  if ! python3 -m pip install --user -U "huggingface_hub[hf_transfer]"; then
    python3 -m pip install --user --break-system-packages -U "huggingface_hub[hf_transfer]"
  fi
fi

if [[ -z "${HF_TOKEN:-}" ]]; then
  log "HF_TOKEN is not set."
  log "Public repos may still download, but gated repos will fail."
  log "If needed, export a token first: export HF_TOKEN=hf_xxx"
fi

log "HF_HOME=${HF_HOME}"
log "HF_HUB_CACHE=${HF_HUB_CACHE}"
log "SMART_MODEL=${SMART_MODEL}"
log "DRAFT_MODEL=${DRAFT_MODEL}"

python3 - <<'PY'
import os
import sys
from huggingface_hub import snapshot_download

models = [
    os.environ["SMART_MODEL"],
    os.environ["DRAFT_MODEL"],
]

cache_dir = os.environ["HF_HOME"]
token = os.environ.get("HF_TOKEN")
workers = int(os.environ.get("HF_DOWNLOAD_WORKERS", "8"))

for repo in models:
    print(f"\n=== Downloading {repo} ===", flush=True)
    try:
        snapshot_download(
            repo_id=repo,
            repo_type="model",
            cache_dir=cache_dir,
            token=token,
            local_files_only=False,
            max_workers=workers,
        )
    except Exception as exc:
        print(f"\nERROR downloading {repo}: {exc}", file=sys.stderr, flush=True)
        sys.exit(1)
    print(f"=== Finished {repo} ===", flush=True)
PY

log "All downloads finished."
log "Cache usage:"
du -sh "${HF_HOME}" || true

log "Cached model directories:"
find "${HF_HUB_CACHE}" -maxdepth 1 -type d -name 'models--*' -printf '%f\n' 2>/dev/null | sort || true