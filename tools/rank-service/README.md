# Swarmfront Rank Service

Dedicated central rank service for player ranking, tiers/colors, leaderboard queries, and matchmaking candidate selection.

## Why this exists

This service is separate from analytics and is the authority for rank state. The game can point `SF_RANK_BACKEND_URL` here and stop relying on local-only rank progression.

## API shape

- Route shape: `POST /v1/rank/<action>`
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

## Beta hardening defaults

- Canonical rank IDs enforced by default: `u_<12 hex chars>` for players, `bot_<6 digits>` for bot seats.
- Debug rank mutation endpoints are disabled by default.
- Admin/ops routes are available under `/v1/admin/*` and use the same bearer token gate as gameplay routes when `RANK_API_TOKEN` is set.

## Wire Godot client

Set environment (or project setting) so rank transport points to this service:

```bash
SF_RANK_BACKEND_URL=http://127.0.0.1:8790/v1/rank
# optional if set on service
SF_RANK_BACKEND_TOKEN=<same-as-RANK_API_TOKEN>
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
