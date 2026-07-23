#!/usr/bin/env bash
# box-provision.sh (#1033) — David's #2146 recipe, CONFIG ONLY, zero OpenWork/Den source patches.
# Stands the single on-box worker into Den: create a destination:"local" worker, launch the
# orchestrator carrying that worker's Den tokens, and link it via a worker_instance row.
# Run from packaging/docker/ after the appliance is up and den is healthy.
set -euo pipefail

DC="docker compose -p appliance-1033 --env-file appliance.env -f docker-compose.appliance.yml"
BOX_URL="${BOX_URL:-http://100.85.150.22:8787}"   # reachable from the den container AND an operator browser (tailscale)
EMAIL="${EMAIL:-demo@wilsch.local}"; PASS="${PASS:-WilschBlockA-2026}"
J="$(mktemp)"; trap 'rm -f "$J"' EXIT

# Persist a KEY=VALUE into the --env-file so a plain `... up` re-reads it after a restart
# (durability, #1038): replace an existing line, else append. Portable across macOS/Linux.
ENV_FILE="appliance.env"
upsert_env() {
  local key="$1" val="$2"
  [ -f "$ENV_FILE" ] || touch "$ENV_FILE"
  if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    grep -v "^${key}=" "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
  fi
  printf '%s=%s\n' "$key" "$val" >> "$ENV_FILE"
}

echo "[1/4] admin session ($EMAIL)"
curl -s --max-time 20 -c "$J" -X POST http://localhost:3005/api/auth/sign-in/email \
  -H "Content-Type: application/json" -H "Origin: http://gx10-017d:3005" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}" >/dev/null

echo "[1b] retire any existing workers (single-worker box)"
for w in $(curl -s -b "$J" http://localhost:8788/v1/workers 2>/dev/null | jq -r '.workers[].id' 2>/dev/null); do
  curl -s -b "$J" -X DELETE "http://localhost:8788/v1/workers/$w" >/dev/null 2>&1 || true
done
docker exec appliance-1033-mysql-1 mysql -uroot -ppassword openwork_den \
  -e "DELETE FROM worker_instance;" 2>/dev/null || true

echo "[2/4] create destination:local worker"
RESP="$(curl -s --max-time 25 -b "$J" -X POST http://localhost:8788/v1/workers \
  -H "Content-Type: application/json" \
  -d '{"name":"Block A Box","destination":"local","workspacePath":"/workspace"}')"
WID="$(echo "$RESP" | jq -r '.worker.id')"
CT="$(echo "$RESP" | jq -r '.tokens.client')"
HT="$(echo "$RESP" | jq -r '.tokens.host')"
[ -n "$WID" ] && [ "$WID" != "null" ] || { echo "worker create failed: $RESP"; exit 1; }
echo "    worker=$WID"

echo "[3/4] persist durable wire into appliance.env + (re)launch orchestrator & chat-spa"
# Durable across a restart (AC3): a later `... up` re-reads these four from --env-file appliance.env,
# so the Den-minted token authenticates again without re-provisioning — the worker row survives in the
# den-mysql-data volume. VITE_OPENWORK_URL/TOKEN are what the browser SPA hydrates on boot (AC1/AC2).
upsert_env OPENWORK_TOKEN "$CT"
upsert_env OPENWORK_HOST_TOKEN "$HT"
upsert_env VITE_OPENWORK_URL "$BOX_URL"
upsert_env VITE_OPENWORK_TOKEN "$CT"
$DC up -d --force-recreate orchestrator chat-spa >/dev/null 2>&1
for i in $(seq 1 40); do
  $DC ps --format '{{.Service}}={{.Health}}' 2>/dev/null | grep -q 'orchestrator=healthy' && break
  sleep 5
done
echo "    orchestrator: $($DC ps --format '{{.Service}}={{.Health}}' 2>/dev/null | grep orchestrator)"
echo "    chat-spa:     $($DC ps --format '{{.Service}}={{.Health}}' 2>/dev/null | grep chat-spa) — SPA hydrates VITE_OPENWORK_URL=$BOX_URL on boot"

echo "[4/4] link to Den (worker_instance row)"
# Reuse the worker's own typeid suffix (a valid 26-char crockford id) — pipefail-safe.
WKI="wki_${WID#wrk_}"
docker exec appliance-1033-mysql-1 mysql -uroot -ppassword openwork_den -e \
  "INSERT INTO worker_instance (id,worker_id,provider,url,status) VALUES ('$WKI','$WID','local','$BOX_URL','healthy');" 2>/dev/null

echo "provisioned: worker=$WID instance=$WKI url=$BOX_URL"

echo "=== VERIFY: Den resolves + /opencode answers (David's chain) ==="
TR="$(curl -s --max-time 25 -b "$J" -X POST "http://localhost:8788/v1/workers/$WID/tokens" -H "Content-Type: application/json" -d '{}')"
URL="$(echo "$TR" | jq -r '.connect.openworkUrl')"
VCT="$(echo "$TR" | jq -r '.tokens.client')"
echo "openworkUrl=$URL"
SID="$(curl -s --max-time 20 -X POST "$URL/opencode/session" -H "Authorization: Bearer $VCT" -H "Content-Type: application/json" -d '{}' | jq -r '.id')"
echo "session=$SID"
curl -s --max-time 40 -X POST "$URL/opencode/session/$SID/message" -H "Authorization: Bearer $VCT" -H "Content-Type: application/json" \
  -d '{"providerID":"local-vllm","modelID":"nvidia/Qwen3.6-35B-A3B-NVFP4","parts":[{"type":"text","text":"Reply with one word: capital of Japan?"}]}' >/dev/null 2>&1 &
sleep 25
echo "answer:"
curl -s --max-time 15 "$URL/opencode/session/$SID/message" -H "Authorization: Bearer $VCT" 2>/dev/null \
  | jq -r '(if type=="array" then . else .messages end)[]|select((.info.role//.role)=="assistant")|((.parts//.info.parts//[])[]|select(.type=="text")|.text)' 2>/dev/null | tail -8
