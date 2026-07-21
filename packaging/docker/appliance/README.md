# Bare Block A - Unified Appliance (WIP - #1033)

Session artifacts toward the unified appliance-compose (serving + OpenWork/Den,
vanilla, latest-pinned). NOT yet the single unified Den compose (AC1) - see Status.

## Proven on the sandbox DGX Spark (gx10-017d, GB10 sm_121) - 2026-07-21
- AC4 - model serves on-box. nvidia/Qwen3.6-35B-A3B-NVFP4 serves on local vLLM :8000,
  offline (HF_HUB_OFFLINE=1), stable + clean output. W4A16 => Marlin is the only supported
  MoE kernel on sm_121; stability + clean chat needed VLLM_MARLIN_USE_ATOMIC_ADD=1,
  --reasoning-parser qwen3, --async-scheduling, --enable-chunked-prefill, cudagraphs on. See serving-up.sh.
- AC5 - worker reaches model direct. OpenCode worker wired to local vLLM via opencode.json
  (provider local-vllm -> host.docker.internal:8000/v1); cloud inference proxy dropped.
  Browser chat -> orchestrator -> vLLM 200 OK, witnessed in Chrome.

## Files
- serving-up.sh - the proven vLLM serving container (AC4).
- opencode.json - OpenCode provider -> local vLLM (AC5). Mount at OPENWORK_WORKSPACE/.opencode/opencode.json.
- .env.example - chat-stack boot env (incl. OPENWORK_PUBLIC_HOST Vite-host fix, DT#1673).
- docker-compose.appliance-override.yml - override on dev.yml: orchestrator extra_hosts (host-gateway) + web OPENWORK_PUBLIC_HOST.

## Status / remaining
- [x] AC4 - model serves on-box (witnessed)
- [x] AC5 - worker/API reaches model direct, no cloud proxy (witnessed)
- [ ] AC6 - Den auth + shared login (current stack is token-mode)
- [ ] AC1 - fold serving + Den + orchestrator into ONE compose + single front door
- [ ] Polish - chat-template/agent-prompt tuning (OpenWork is an agent harness); serving perf
