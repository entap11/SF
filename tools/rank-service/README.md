# ENTaP Identity / Rank Service

First ENTaP platform identity authority, currently hosted in the historical `tools/rank-service` package. For Swarmfront beta, the required production surface is identity creation only; rank features can remain dormant.

## Why this exists

This service is separate from analytics and the VS backend. The game points `SF_RANK_BACKEND_URL` here so account creation can receive server-assigned UUIDv7 internal IDs and public ENTaP IDs.

## API shape

- Beta identity route: `POST /v1/rank/register_player`
- General route shape: `POST /v1/rank/<action>`
- Matches `/Users/home/SideProjects/SF/project/docs/rank_backend_contract.md`
- Responses use `{ "ok": true, ... }` / `{ "ok": false, "err": "..." }`

## Setup

```bash
cd tools/rank-service
cp .env.example .env
docker compose up -d
npm install
npm run dev
```

Migrations also run automatically on service startup. You can run them manually with:

```bash
npm run migrate
```

Default server: `http://127.0.0.1:8790`

From project root, you can also start rank service + Godot together:

```bash
./tools/run_with_rank_service.sh
```

If your Postgres is not on the default local URL, set it before launch:

```bash
RANK_DATABASE_URL=postgres://user:pass@host:5432/swarmfront_rank ./tools/run_with_rank_service.sh
```

Identity-only smoke against a real Postgres URL:

```bash
RANK_DATABASE_URL=postgres://user:pass@host:5432/swarmfront_rank ./tools/run_rank_identity_smoke.sh
```

## Beta identity contract

- Client sends `call_sign`, `region`, and optional `install_metadata`.
- Client does not send an authoritative account ID during beta account creation.
- Service assigns UUIDv7 `id`.
- Service assigns sequential public `entap_id` using `rank_entap_id_seq`.
- Duplicate call signs return `409` with `err=call_sign_not_unique`.
- Canonical rank IDs are UUIDv7 for human players and `bot_<6 digits>` for bot seats.
- Debug rank mutation endpoints are disabled by default.
- Admin/ops routes are available under `/v1/admin/*` and use the same bearer token gate as gameplay routes when `RANK_API_TOKEN` is set.

## Wire Godot client

Set environment (or project setting) so rank transport points to this service:

```bash
SF_RANK_BACKEND_URL=http://127.0.0.1:8790/v1/rank
# optional if set on service
SF_RANK_BACKEND_TOKEN=<same-as-RANK_API_TOKEN>
```

For staging/production beta builds, configure the deployed Render URL instead of the local URL.

## Render staging deployment

The repo root includes `render.yaml` for a separate staging web service and Postgres database:

- Web service: `entap-identity-rank-staging`
- Database: `entap-identity-rank-staging-db`
- Root directory: `tools/rank-service`
- Build command: `npm ci && npm run build`
- Start command: `npm run start`
- Health check: `/health`

After deployment, set a real `RANK_API_TOKEN`, run migrations if needed, then smoke:

```bash
RANK_SMOKE_BASE_URL=https://YOUR-RANK-STAGING.onrender.com/v1/rank \
RANK_SMOKE_TOKEN=$RANK_API_TOKEN \
npm run smoke:identity
```

## Persistence

- Source of truth is Postgres (`DATABASE_URL`).
- `RANK_STATE_PATH` is legacy import only. If a JSON state file exists and DB is empty, service imports it once on startup.

## Real-time guarantees

- Rank writes are synchronous DB transactions.
- Match result applies wax + recomputes tier/color/rank immediately.
- Response is returned only after commit, so a player crossing a tier threshold is promoted as they exit that match.
- Demotion smoothing defaults to 5 pass-through slots (`RANK_TIER_DEMOTION_GRACE_SLOTS=5`), and overflow in a full tier is pushed upward by promoting the top edge into the next tier.

## Admin endpoints

- `GET /health/details`
- `GET /v1/admin/players/:playerId`
- `GET /v1/admin/tier-counts`
- `GET /v1/admin/audit`
- `POST /v1/admin/recompute`

## Beta simulation

Run a repeatable ladder simulation without needing a live DB:

```bash
cd tools/rank-service
npm run simulate:beta -- --players=600 --matches=3000 --seed=1337
```

This prints a JSON summary of tier distribution, color distribution, and top players so you can sanity check unlock/open-tier behavior before putting real testers on the service.
