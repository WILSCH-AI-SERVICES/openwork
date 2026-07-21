#!/usr/bin/env bash
# Proven Qwen3.6-35B-A3B-NVFP4 serving on the sandbox DGX Spark (gx10-017d, GB10 sm_121).
# Solo single-node adaptation of spark-vllm-docker recipe qwen3.6-35b-a3b-nvfp4-no-mtp
# (branch feat/deepseek-v4-flash-dspark). AC4 witnessed 2026-07-21: stable, offline, clean output.
set -euo pipefail
HF_CACHE="${HF_CACHE:-/home/verdant/.cache/huggingface}"
docker stop serving 2>/dev/null || true; docker rm serving 2>/dev/null || true
docker run -d --name serving --gpus all --network host --ipc host --shm-size 8g \
  -v "$HF_CACHE:/root/.cache/huggingface" \
  -v /home/verdant/.cache/vllm:/root/.cache/vllm \
  -v /home/verdant/.cache/flashinfer:/root/.cache/flashinfer \
  -v /home/verdant/.triton:/root/.triton -v /home/verdant/.tilelang:/root/.tilelang \
  -e HF_HUB_OFFLINE=1 -e HF_HOME=/root/.cache/huggingface \
  -e TORCH_CUDA_ARCH_LIST=12.1a -e FLASHINFER_CUDA_ARCH_LIST=12.1a \
  -e VLLM_MARLIN_USE_ATOMIC_ADD=1 \
  vllm-node:latest \
  vllm serve nvidia/Qwen3.6-35B-A3B-NVFP4 --host 0.0.0.0 --port 8000 \
    --tensor-parallel-size 1 --trust-remote-code --kv-cache-dtype fp8 \
    --attention-backend flashinfer --moe-backend marlin \
    --gpu-memory-utilization 0.6 --max-model-len 32768 --max-num-seqs 4 --max-num-batched-tokens 8192 \
    --enable-chunked-prefill --async-scheduling --enable-prefix-caching --load-format fastsafetensors \
    --reasoning-parser qwen3 --tool-call-parser qwen3_xml --enable-auto-tool-choice
