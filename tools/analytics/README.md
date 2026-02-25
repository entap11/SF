# Swarmfront Analytics (Phase 0 + Phase 1-ready)

Node/TypeScript analytics backend + internal dashboard for beta KPIs.

## What this includes

Phase 0 implemented:
- Event ingestion API with idempotent dedupe by `event_id`
- Postgres schema + migrations
- Daily/hourly rollup jobs
- Internal dashboard pages
  - Overview
  - Retention
  - Gameplay
  - Stability
- Basic admin auth backed by `admin_users`

Phase 1-safe foundation:
- Stable event envelope + JSON `props`
- Rollup architecture separated from ingest path
- Can add new event names/rollups without breaking Phase 0 data

## Directory

- `src/server.ts` main service
- `src/sql/migrations/001_phase0_init.sql` schema
- `src/events/*` validation + ingest
- `src/rollups/*` KPI aggregation
- `src/dashboard/*` internal web UI
- `src/cli/migrate.ts` run migrations
- `src/cli/create_admin_user.ts` create/update admin user
- `src/cli/rollup.ts` backfill rollups

## Event API

### `POST /v1/events/batch`

Request body:
```json
{
  "events": [
    {
      "event_id": "uuid",
      "event_name": "session_start",
      "event_time_utc_ms": 1730000000000,
      "install_id": "uuid",
      "session_id": "uuid",
      "app_version": "0.9.0",
      "platform": "ios",
      "props": {}
    }
  ]
}
```

Response:
```json
{
  "accepted_count": 1,
  "duplicate_count": 0,
  "invalid_count": 0,
  "results": [
    { "event_id": "uuid", "status": "accepted" }
  ]
}
```

### `POST /v1/events/single`

Same schema as one event object.

## Dashboard routes (basic auth required)

- `/dashboard`
- `/dashboard/retention`
- `/dashboard/gameplay`
- `/dashboard/stability`

## Setup

1. Copy env file
```bash
cp .env.example .env
```

2. Install dependencies
```bash
npm install
```

Optional local Postgres:
```bash
docker compose up -d
```

3. Run migrations
```bash
npm run migrate
```

4. Generate admin user (optional override)
```bash
npm run create-admin-user -- --username=Mattballou --password='$warmFr0nt'
```

5. Start dev server
```bash
npm run dev
```

Server default: `http://localhost:8787`
Default bind is loopback only (`127.0.0.1`) so it is not reachable from other devices unless you explicitly change `BIND_HOST`.

## Rollups

Manual run for one day:
```bash
npm run rollup -- --date=2026-02-24
```

Manual range backfill:
```bash
npm run rollup -- --start=2026-02-01 --end=2026-02-24
```

Scheduler (enabled by default):
- Hourly “today so far” rollup (UTC)
- Daily rollover pass (UTC)

## Required env vars

- `DATABASE_URL`
- `PORT` (optional, default `8787`)
- `BIND_HOST` (optional, default `127.0.0.1`)
- `INGEST_BATCH_MAX` (optional, default `100`)
- `ADMIN_AUTH_REALM` (optional)
- `ENABLE_ROLLUP_SCHEDULER` (optional, default `true`)
- `ROLLUP_HOURLY_ENABLED` (optional, default `true`)
- `ROLLUP_DAILY_ENABLED` (optional, default `true`)

Bootstrap admin (defaults are pre-set for local beta):
- `ADMIN_BOOTSTRAP_USERNAME`
- `ADMIN_BOOTSTRAP_PASSWORD`

## Beta client integration expectations

Client should:
- generate/persist `install_id` once
- generate `session_id` per foreground session
- include stable envelope fields on every event
- queue offline and flush in batches
- flush on `session_end`, `match_end`, and periodic timer
- retry with backoff

This service already supports dedupe-safe retries by `event_id`.
