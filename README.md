Note: this project is not yet working. Do not try it at home yet.

# Strix Halo — vLLM Mistral Small 4 + Eagle (gfx1151)

This repo runs a **single vLLM server** on **AMD Ryzen AI Max “Strix Halo” (gfx1151)** using:

- Smart model: `mistralai/Mistral-Small-4-119B-2603`
- Draft model: `mistralai/Mistral-Small-4-119B-2603-eagle` (Eagle speculative decoding)
- Backend: ROCm/TheRock on gfx1151 via `kyuz0/vllm-therock-gfx1151` or an official AMD vLLM dev image.

The goal is to maximize tokens/second on this specific hardware + model pair using vLLM's Eagle speculative decoding.

## 1. Prerequisites

- AMD Strix Halo APU (Ryzen AI Max 395+ / gfx1151) with ROCm-compatible kernel and firmware.
- Docker and docker-compose plugin.
- Host filesystem with fast storage mounted at `/mnt/data` (or update `config.env` paths).

For host ROCm/kernel tuning, see the Strix Halo vLLM toolbox docs and ROCm vLLM image guide.

## 2. Configure

Edit `config.env` as needed:

- `VLLM_BASE_IMAGE` — base image (default: `docker.io/kyuz0/vllm-therock-gfx1151:latest`).
- `SERVER_PORT` — external port (default: 8000).
- `VLLM_SMART_MODEL` / `VLLM_DRAFT_MODEL` — smart + draft model IDs.
- `VLLM_MAX_MODEL_LEN`, `VLLM_MAX_NUM_SEQS`, `VLLM_MAX_BATCH_TOKENS`, `VLLM_GPU_MEM_UTIL` — throughput/latency tuning.
- `HF_CACHE`, `VLLM_CACHE`, `VLLM_DOWNLOAD_DIR` — host paths for caches and model weights.

## 3. Start the server

```bash
./start.sh
```

This will:

1. Build `strix-vllm-mistral:local` (thin wrapper over `VLLM_BASE_IMAGE`).
2. Start the container with ROCm/vLLM env tuned for gfx1151.
3. Wait for `http://localhost:8000/v1/models` to become ready.
4. Print the OpenAI-compatible base URL.

You can then query it with any OpenAI-compatible client, for example:

```bash
curl -X POST "http://localhost:8000/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistralai/Mistral-Small-4-119B-2603",
    "messages": [
      {"role": "user", "content": "Hello from Strix Halo!"}
    ]
  }'
```

## 4. Benchmark tokens/s

Once the server is running, use:

```bash
./bench_current.sh
```

This will:

1. Exec into the running container.
2. Detect the currently served model via `/v1/models`.
3. Run a warm-up request.
4. Run a timed `/v1/chat/completions` call with `max_tokens=512`.
5. Print completion tokens, elapsed seconds and tokens/s.

Use this to compare different values of `VLLM_NUM_SPEC_TOKENS`, `VLLM_MAX_NUM_SEQS`, `VLLM_MAX_BATCH_TOKENS`, and `VLLM_MAX_MODEL_LEN` in `config.env`.

## 5. Stop the server

```bash
./stop.sh
```

This stops and removes the `strix-vllm-mistral` container.

# TODO

## Find a new quantized version of the Mistral model
```
The cyankiwi AWQ quant was made with group size 32. This vLLM ROCm build's only available WNA16 kernels (ConchLinearKernel for AMD, ExllamaLinearKernel) require group size 128 or -1 (per-channel). It's a hard incompatibility
```