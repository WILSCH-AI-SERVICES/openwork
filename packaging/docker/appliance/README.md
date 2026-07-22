# Bare Block A — the unified appliance (#1033)

One `docker compose` stands up the whole standing box on a Wilsch-side sandbox DGX Spark
(gx10-017d): **serving** (on-box vLLM) + the **OpenWork worker-runtime** + **Den** (named-user
login). Built **vanilla** — upstream's own packaging configured by environment, **zero source
patches**. The whole Wilsch delta is this folder + `docker-compose.appliance.yml` + `.env`.

Design: `kab-baustein-a-build-design` Part 6 (The Compose) + Part 7 (The Login Path).
Recipe verified against David's spike **#2146** (deliverable-tracking) — config-only, no fork.

## What's in the box (all from one compose)

| Service | Role |
|---|---|
| `serving` | on-box vLLM, Qwen3.6-35B-A3B-NVFP4, offline (proven recipe → `serving-up.sh`) |
| `orchestrator` | the OpenWork worker-runtime (OpenCode subprocess inside), `:8787` |
| `den` · `web` · `worker-proxy` · `mysql` | Den's login half — vanilla `docker-compose.den-dev.yml`, **included untouched** |
| `chat-spa` | the `@openwork/app` web UI, `:5173` (see "Chat surface" below) |

## Version pin (why not `dev` tip)

The checkout is pinned to **`dd9d631d`** (upstream, 2026-05-11) — the last commit where the
**vanilla Den image builds**. From `37988d78` onward (the React-Email refactor, incl. tags
`v0.13.10/11/12`) `packaging/docker/Dockerfile.den` is missing `COPY packages/email`, so
`den-api` fails `tsc` with `TS2307: Cannot find module '@openwork/email'`. Pinning avoids the
patch entirely and holds version-lock by construction (one checkout → orchestrator + SPA + Den
all one tag). **This is an upstream bug — report it** (David hit the identical break in #2146).

## Setup

```bash
cd packaging/docker
cp appliance/.env.example appliance.env          # then edit DEN_PUBLIC_HOST etc. for this box
docker compose -p appliance-1033 --env-file appliance.env -f docker-compose.appliance.yml up -d --build
# wait for den healthy, then stand the single on-box worker into Den (David's #2146 recipe):
bash appliance/box-provision.sh
```

`box-provision.sh` is the whole Den↔worker wire, **config only, no source patches** (this is the
key learning from #2146):
1. create a `destination:"local"` worker → get its Den client/host tokens
2. relaunch the `orchestrator` container **carrying those tokens** (`--openwork-token …`)
3. `INSERT` a `worker_instance` row (`url = http://<box>:8787`, `status: healthy`) — Den has **no
   register-local-worker API**, so this row is the required link
4. verify: signed-in user → `POST /v1/workers/:id/tokens` → Den resolves `openworkUrl` →
   chat via the worker's `/opencode/*` proxy → on-box answer

The shared demo login is stood up by hand (Den web, `:3005`), the one confirmation code caught on
the box console (`OPENWORK_DEV_MODE=1`, no outside mail) — Part 7.

## Model wire

`opencode-config/opencode.json` (mounted into the worker via `OPENWORK_DEV_OPENCODE_IMPORT_CONFIG_DIR`)
points OpenCode **direct** at local vLLM (`http://host.docker.internal:8000/v1`); OpenWork's cloud
inference proxy is dropped. No Den-UI provider row needed — the box ships wired.

## Chat surface (status)

- **Works today:** the worker's built-in UI (`/w/<ws>/ui#token=…`) and the OpenCode HTTP API —
  a signed-in user gets a genuine on-box answer in a browser. Verified end-to-end ("Tokyo").
- **`#1034` (open):** the polished `@openwork/app` SPA can't attach a self-hosted worker in a pure
  browser — *Connect custom remote* needs the Electron desktop helper (`workspaceCreateRemote`),
  *Shared workspaces* routes to OpenWork Cloud. ARCHIBUS solved this with a Vercel web-build +
  the `clientMode` fork (#1848) — a fork, deferred for the vanilla box (build design Part 4).

## AC status (for /ac-falsify)

AC1 (one compose, both halves healthy) ✅ · AC2/AC3 (version-lock, vanilla) ✅ by pin ·
AC4 (model serves offline) ✅ · AC5 (worker → model direct) ✅ · AC6 (shared login, on-box OTP) ✅.
Browser-SPA chat is out of AC scope (worker/API layer) — it's sibling spike #1034.
