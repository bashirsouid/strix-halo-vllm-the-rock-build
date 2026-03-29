# Dockerfile
# AMD Strix Halo (gfx1151) — vLLM container for Mistral Small 4 + Eagle
#
# This image is a thin wrapper around kyuz0's vLLM toolbox image, which
# contains a TheRock-based ROCm stack, a Strix Halo–patched vLLM build,
# and all required dependencies for running vLLM on gfx1151.
#
# You normally do not need to edit this file. To change the base image
# (for example to an official AMD vLLM dev image), set VLLM_BASE_IMAGE
# in config.env and re-run ./start.sh.

ARG VLLM_BASE_IMAGE=rocm/vllm-dev:latest
FROM ${VLLM_BASE_IMAGE}

SHELL ["/bin/bash", "-lc"]

RUN mkdir -p /workspace /root/.cache/huggingface /root/.cache/vllm /models
WORKDIR /workspace

ENTRYPOINT ["vllm"]
