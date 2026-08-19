#!/usr/bin/env bash
# box-up.sh — bring the whole KaB Baustein A appliance up in one command (#1048).
#
# The model serve is sourced from the spark-vllm-docker recipe system (run-recipe.sh),
# NOT a hand-copied vLLM argv. run-recipe.sh --solo launches a --network host container,
# so vLLM lands on the host :8000 exactly as the proven serve did (appliance/serving-up.sh) —
# the orchestrator still reaches it via host.docker.internal:8000, unchanged. Offline env
# (HF_HUB_OFFLINE + GB10 arch) is carried by the recipe.
#
# The rest of the appliance (Den login half via the include, orchestrator, chat SPA) comes
# up via the compose file, which no longer defines a serving service.
#
# Fallback: if the recipe cannot drive the solo / host-network / offline serve, bring the
# serve up with appliance/serving-up.sh (the retained hand-copied argv) and then run the
# compose step below with SERVE_NAME set to the container that fallback started
# (SERVE_NAME=serving ./box-up.sh) — the serve is identified by container, never by whoever
# happens to hold the port, so an operator reusing their own serve names it.
#
# Paths are per-deployment, not per-author: SPARK_VLLM_DIR (the spark-vllm-docker checkout)
# and HF_HOME (the weight cache) default under the invoking operator's $HOME and are each
# overridable, so the box comes up for whoever runs it (#1071). On a shared box where the
# weights live in another account's cache, point HF_HOME at that cache explicitly.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

SPARK_VLLM_DIR="${SPARK_VLLM_DIR:-$HOME/spark-vllm-docker}"
RECIPE="${RECIPE:-qwen3.6-35b-a3b-nvfp4-no-mtp}"
export HF_HOME="${HF_HOME:-$HOME/.cache/huggingface}"
SERVE_NAME="${SERVE_NAME:-appliance-serving}"
COMPOSE_PROJECT="${COMPOSE_PROJECT:-appliance-1033}"
COMPOSE_FILE="docker-compose.appliance.yml"
SERVE_PORT="${SERVE_PORT:-8000}"

# Preflight: an unreadable checkout used to surface as a bare exit 126 from line 34, with
# nothing naming the cause. Fail here instead, pointing at the override that fixes it.
if [ ! -x "$SPARK_VLLM_DIR/run-recipe.sh" ]; then
  echo "[box-up]   ERROR: no executable run-recipe.sh at $SPARK_VLLM_DIR" >&2
  echo "[box-up]          set SPARK_VLLM_DIR to your spark-vllm-docker checkout, e.g." >&2
  echo "[box-up]          SPARK_VLLM_DIR=\$HOME/spark-vllm-docker ./box-up.sh" >&2
  exit 1
fi

echo "[box-up] 1/3 — model serve via run-recipe.sh ($RECIPE, host :$SERVE_PORT)"
if docker ps --format '{{.Names}}' | grep -q "^${SERVE_NAME}$"; then
  echo "[box-up]   serve container ${SERVE_NAME} already running — leaving it"
else
  # A serve this run did not start must not be mistaken for the appliance's own (#1075).
  # Refuse here rather than launching beside it and certifying it at the readiness check.
  if curl -sf "http://localhost:$SERVE_PORT/v1/models" >/dev/null 2>&1; then
    echo "[box-up]   ERROR: host :$SERVE_PORT already answers, but ${SERVE_NAME} is not running" >&2
    echo "[box-up]          a serve this run did not start holds the port; the appliance cannot" >&2
    echo "[box-up]          take its identity from it. Free :$SERVE_PORT, or set SERVE_NAME to the" >&2
    echo "[box-up]          container that serve runs in if it is yours." >&2
    exit 1
  fi
  docker rm -f "$SERVE_NAME" >/dev/null 2>&1 || true
  "$SPARK_VLLM_DIR/run-recipe.sh" "$RECIPE" --solo -d --name "$SERVE_NAME"
fi

echo "[box-up]   waiting for ${SERVE_NAME} to answer on :$SERVE_PORT ..."
for i in $(seq 1 120); do
  # Our container's liveness gates the verdict, and is checked BEFORE the port: a bare port
  # probe passes against any serve on the host, which is how a removed ${SERVE_NAME} once
  # reported healthy against another operator's serve (#1071 ledger, infrastructure-note).
  if ! docker ps --format '{{.Names}}' | grep -q "^${SERVE_NAME}$"; then
    echo "[box-up]   ERROR: serve container ${SERVE_NAME} is not running — the appliance has no serve of its own" >&2
    docker logs --tail 40 "$SERVE_NAME" 2>&1 || true
    exit 1
  fi
  if curl -sf "http://localhost:$SERVE_PORT/v1/models" >/dev/null 2>&1; then echo "[box-up]   serve healthy (${SERVE_NAME})"; break; fi
  if [ "$i" = 120 ]; then echo "[box-up]   ERROR: ${SERVE_NAME} did not become healthy in time" >&2; exit 1; fi
  sleep 5
done

echo "[box-up] 2/3 — appliance stack via compose (Den + orchestrator + chat SPA)"
ENV_ARGS=""; [ -f appliance.env ] && ENV_ARGS="--env-file appliance.env"
  docker compose -p "$COMPOSE_PROJECT" $ENV_ARGS -f "$COMPOSE_FILE" up -d --wait

# Re-assert ownership at the moment success is declared: the compose step above takes
# minutes, and the serve can die inside it while every earlier check still passed.
if ! docker ps --format '{{.Names}}' | grep -q "^${SERVE_NAME}$"; then
  echo "[box-up]   ERROR: serve container ${SERVE_NAME} is no longer running" >&2
  echo "[box-up]          refusing to report the appliance up without a serve of its own" >&2
  exit 1
fi

echo "[box-up] 3/3 — appliance up. serve=$SERVE_NAME (host :$SERVE_PORT) · worker :8787 · chat :5173"
docker compose -p "$COMPOSE_PROJECT" ${ENV_ARGS:-} -f "$COMPOSE_FILE" ps
