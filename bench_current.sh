#!/usr/bin/env bash
# bench_current.sh — quick tokens/s sanity benchmark against the running vLLM container.
#
# This script:
#   1) Ensures the strix-vllm-mistral container is running.
#   2) Runs a single /v1/chat/completions request from inside the container.
#   3) Uses the OpenAI-compatible "usage.completion_tokens" field to compute tokens/s.
#
# Requirements:
#   - ./start.sh has already been run and the server is up.
#   - The base image includes Python and the "requests" package (true for kyuz0's toolbox).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! docker ps -q --filter "name=strix-vllm-mistral" --filter "status=running" | grep -q .; then
  echo "[bench_current] Container strix-vllm-mistral is not running. Start it with ./start.sh first." >&2
  exit 1
fi

PORT="${SERVER_PORT:-8000}"

docker exec -e BENCH_PORT="${PORT}" strix-vllm-mistral \
  /usr/bin/env python - << 'PY'
import os
import time
import json

import requests

port = os.environ.get("BENCH_PORT", "8000")
base_url = f"http://127.0.0.1:{port}/v1"

# Detect the currently served model
models = requests.get(f"{base_url}/models", timeout=30).json()
model_id = models["data"][0]["id"]

prompt = "You are a helpful assistant. Write a short story about an adventurous robot exploring Mars."

payload = {
    "model": model_id,
    "messages": [
        {"role": "user", "content": prompt},
    ],
    "max_tokens": 512,
    "temperature": 0.2,
}

# Warm-up request (jit, kernels, cache, etc.)
requests.post(f"{base_url}/chat/completions", json=payload, timeout=120)

start = time.perf_counter()
resp = requests.post(f"{base_url}/chat/completions", json=payload, timeout=300)
elapsed = time.perf_counter() - start

resp.raise_for_status()
out = resp.json()

usage = out.get("usage", {})
completion_tokens = usage.get("completion_tokens")
if not completion_tokens:
    # Fallback: rough estimate from output length
    text = out["choices"][0]["message"]["content"]
    completion_tokens = max(1, len(text.split()))

tps = completion_tokens / elapsed
print(f"Model           : {model_id}")
print(f"Completion toks : {completion_tokens}")
print(f"Elapsed (s)     : {elapsed:.3f}")
print(f"Tokens/s        : {tps:.1f}")
PY

